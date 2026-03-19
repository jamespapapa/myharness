import { readdirSync } from "node:fs";
import { access } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

import { buildOntology, readOntologyGraph } from "../../ontology/src/index.js";
import {
  basenameLabel,
  chunkText,
  createProjectId,
  nowIso,
  openProjectDatabase,
  resolveDataRoot,
  resolveProjectDbPath,
  type FileContentResponse,
  type IndexRequest,
  type IndexWarning,
  type ProjectSummary,
  withTransaction,
} from "../../shared/src/index.js";
import { extractFileArtifact } from "./extractors.js";
import { applyRepoScores, buildRepoCards } from "./repoMap.js";
import { scanRepository } from "./scanner.js";
import { clearProjectData, initializeProjectSchema } from "./schema.js";

export async function indexProject(request: IndexRequest): Promise<ProjectSummary> {
  await access(request.repoPath, fsConstants.R_OK);

  const projectName = request.projectName?.trim() || basenameLabel(request.repoPath);
  const projectId = createProjectId(request.repoPath, projectName);
  const db = openProjectDatabase({ projectId });
  initializeProjectSchema(db);

  const runId = randomUUID();
  const startedAt = nowIso();
  const warnings: IndexWarning[] = [];

  upsertProject(db, projectId, projectName, request.repoPath, "indexing", startedAt, null);
  db.prepare(
    `
      insert into index_runs (run_id, project_id, status, started_at, warnings_json)
      values (?, ?, 'indexing', ?, '[]')
    `,
  ).run(runId, projectId, startedAt);

  try {
    const scanResult = await scanRepository(request.repoPath);
    warnings.push(...scanResult.warnings);

    const artifacts = applyRepoScores(
      scanResult.files.map((file) => {
        const artifact = extractFileArtifact(file);
        warnings.push(...artifact.warnings);
        return artifact;
      }),
    );

    const repoCards = buildRepoCards(artifacts);
    const graph = buildOntology({ projectId, projectName, files: artifacts });

    withTransaction(db, () => {
      clearProjectData(db, projectId);
      persistArtifacts(db, projectId, artifacts);
      persistRepoCards(db, projectId, repoCards);
      persistGraph(db, projectId, graph);
      upsertProject(db, projectId, projectName, request.repoPath, "ready", startedAt, nowIso());
      db.prepare(
        `
          update index_runs
          set status = 'ready',
              finished_at = ?,
              indexed_files = ?,
              warnings_json = ?
          where run_id = ?
        `,
      ).run(nowIso(), artifacts.length, JSON.stringify(warnings), runId);
    });
  } catch (error) {
    const finishedAt = nowIso();
    upsertProject(db, projectId, projectName, request.repoPath, "error", startedAt, finishedAt);
    db.prepare(
      `
        update index_runs
        set status = 'error',
            finished_at = ?,
            warnings_json = ?
        where run_id = ?
      `,
    ).run(
      finishedAt,
      JSON.stringify([
        ...warnings,
        {
          code: "index.failed",
          message: error instanceof Error ? error.message : String(error),
        },
      ]),
      runId,
    );
    throw error;
  } finally {
    db.close();
  }

  return getProjectSummary(projectId) ?? {
    projectId,
    name: projectName,
    repoPath: request.repoPath,
    status: "ready",
    indexedAt: nowIso(),
    stats: { files: 0, symbols: 0, routes: 0, components: 0 },
    warnings,
  };
}

export function listProjects(): ProjectSummary[] {
  const dataRoot = resolveDataRoot();
  const projects: ProjectSummary[] = [];

  try {
    const directories = readdirSyncCompat(dataRoot);
    for (const directory of directories) {
      const projectId = directory;
      const dbPath = resolveProjectDbPath(projectId);
      try {
        const db = openProjectDatabase({ projectId, readOnly: true });
        initializeProjectSchema(db);
        const summary = readProjectSummary(db, projectId);
        if (summary) {
          projects.push(summary);
        }
        db.close();
      } catch {
        continue;
      }
    }
  } catch {
    return [];
  }

  return projects.sort((left, right) => (right.indexedAt ?? "").localeCompare(left.indexedAt ?? ""));
}

export function getProjectSummary(projectId: string): ProjectSummary | null {
  const db = openProjectDatabase({ projectId, readOnly: true });
  try {
    initializeProjectSchema(db);
    return readProjectSummary(db, projectId);
  } finally {
    db.close();
  }
}

export function getProjectFileContent(projectId: string, filePath: string): FileContentResponse | null {
  const db = openProjectDatabase({ projectId, readOnly: true });
  try {
    const row = db
      .prepare(
        `
          select file_path, language, content, line_count
          from files
          where project_id = ? and file_path = ?
          limit 1
        `,
      )
      .get(projectId, filePath) as
      | {
          file_path: string;
          language: string;
          content: string;
          line_count: number;
        }
      | undefined;

    if (!row) {
      return null;
    }

    return {
      filePath: row.file_path,
      language: row.language,
      content: row.content,
      lineCount: row.line_count,
    };
  } finally {
    db.close();
  }
}

export function getProjectGraph(projectId: string): ReturnType<typeof readOntologyGraph> {
  const db = openProjectDatabase({ projectId, readOnly: true });
  try {
    return readOntologyGraph(db, projectId);
  } finally {
    db.close();
  }
}

export function openProjectDb(projectId: string, readOnly = false): DatabaseSync {
  const db = openProjectDatabase({ projectId, readOnly });
  initializeProjectSchema(db);
  return db;
}

function persistArtifacts(db: DatabaseSync, projectId: string, artifacts: ReturnType<typeof applyRepoScores>): void {
  const insertScanFile = db.prepare(
    `
      insert into scan_files (project_id, file_path, sha256, size, language)
      values (?, ?, ?, ?, ?)
    `,
  );
  const insertFile = db.prepare(
    `
      insert into files (project_id, file_path, language, sha256, size, line_count, content)
      values (?, ?, ?, ?, ?, ?, ?)
    `,
  );
  const insertImport = db.prepare(
    `
      insert into imports (project_id, file_path, source, line_start, line_end)
      values (?, ?, ?, ?, ?)
    `,
  );
  const insertSymbol = db.prepare(
    `
      insert into symbols (project_id, file_path, symbol_name, symbol_type, line_start, line_end, signature, heuristic)
      values (?, ?, ?, ?, ?, ?, ?, ?)
    `,
  );
  const insertRoute = db.prepare(
    `
      insert into spring_routes (project_id, file_path, method, route, handler_symbol, line_start, line_end)
      values (?, ?, ?, ?, ?, ?, ?)
    `,
  );
  const insertApiCall = db.prepare(
    `
      insert into api_calls (project_id, file_path, target, kind, line_start, line_end)
      values (?, ?, ?, ?, ?, ?)
    `,
  );
  const insertVueComponent = db.prepare(
    `
      insert into vue_components (project_id, file_path, component_name, line_start, line_end)
      values (?, ?, ?, ?, ?)
    `,
  );
  const insertBuildDependency = db.prepare(
    `
      insert into build_dependencies (project_id, file_path, dependency_name, version)
      values (?, ?, ?, ?)
    `,
  );
  const insertFtsChunk = db.prepare(
    `
      insert into fts_documents (project_id, file_path, symbol_name, line_start, line_end, chunk_text)
      values (?, ?, ?, ?, ?, ?)
    `,
  );
  const insertVecChunk = db.prepare(
    `
      insert into vec_chunks (project_id, file_path, line_start, line_end, chunk_text, embedding_json)
      values (?, ?, ?, ?, ?, null)
    `,
  );

  for (const artifact of artifacts) {
    insertScanFile.run(projectId, artifact.relativePath, artifact.sha256, artifact.size, artifact.language);
    insertFile.run(projectId, artifact.relativePath, artifact.language, artifact.sha256, artifact.size, artifact.lineCount, artifact.content);

    for (const importSignal of artifact.imports) {
      insertImport.run(projectId, importSignal.filePath, importSignal.source, importSignal.lineStart, importSignal.lineEnd);
    }

    for (const symbol of artifact.symbols) {
      insertSymbol.run(
        projectId,
        symbol.filePath,
        symbol.symbolName,
        symbol.symbolType,
        symbol.lineStart,
        symbol.lineEnd,
        symbol.signature,
        symbol.heuristic ? 1 : 0,
      );
    }

    for (const route of artifact.routes) {
      insertRoute.run(projectId, route.filePath, route.method, route.route, route.handlerSymbol, route.lineStart, route.lineEnd);
    }

    for (const apiCall of artifact.apiCalls) {
      insertApiCall.run(projectId, apiCall.filePath, apiCall.target, apiCall.kind, apiCall.lineStart, apiCall.lineEnd);
    }

    if (artifact.componentName) {
      insertVueComponent.run(projectId, artifact.relativePath, artifact.componentName, 1, artifact.lineCount);
    }

    for (const dependency of artifact.buildDependencies) {
      insertBuildDependency.run(projectId, dependency.filePath, dependency.name, dependency.version);
    }

    for (const chunk of chunkText(artifact.content, 26, 8)) {
      const owningSymbol =
        artifact.symbols.find((symbol) => chunk.lineStart >= symbol.lineStart && chunk.lineEnd <= symbol.lineEnd)?.symbolName ?? null;
      insertFtsChunk.run(projectId, artifact.relativePath, owningSymbol, chunk.lineStart, chunk.lineEnd, chunk.text);
      insertVecChunk.run(projectId, artifact.relativePath, chunk.lineStart, chunk.lineEnd, chunk.text);
    }
  }
}

function persistRepoCards(
  db: DatabaseSync,
  projectId: string,
  repoCards: ReturnType<typeof buildRepoCards>,
): void {
  db.prepare(
    `
      insert into repo_cards (project_id, summary, top_entries_json)
      values (?, ?, ?)
    `,
  ).run(projectId, repoCards.repoCard.summary, repoCards.repoCard.topEntriesJson);

  const insertModuleCard = db.prepare(
    `
      insert into module_cards (project_id, module_name, summary, score)
      values (?, ?, ?, ?)
    `,
  );
  const insertFileCard = db.prepare(
    `
      insert into file_cards (project_id, file_path, summary, score)
      values (?, ?, ?, ?)
    `,
  );
  const insertSymbolCard = db.prepare(
    `
      insert into symbol_cards (project_id, file_path, symbol_name, line_start, summary, score)
      values (?, ?, ?, ?, ?, ?)
    `,
  );

  for (const moduleCard of repoCards.moduleCards) {
    insertModuleCard.run(projectId, moduleCard.moduleName, moduleCard.summary, moduleCard.score);
  }
  for (const fileCard of repoCards.fileCards) {
    insertFileCard.run(projectId, fileCard.filePath, fileCard.summary, fileCard.score);
  }
  for (const symbolCard of repoCards.symbolCards) {
    insertSymbolCard.run(projectId, symbolCard.filePath, symbolCard.symbolName, symbolCard.lineStart, symbolCard.summary, symbolCard.score);
  }
}

function persistGraph(
  db: DatabaseSync,
  projectId: string,
  graph: ReturnType<typeof buildOntology>,
): void {
  const insertNode = db.prepare(
    `
      insert into ontology_nodes (node_id, project_id, label, node_type, file_path, symbol_name, metadata_json)
      values (?, ?, ?, ?, ?, ?, ?)
    `,
  );
  const insertEdge = db.prepare(
    `
      insert into ontology_edges (edge_id, project_id, source_id, target_id, edge_type, heuristic, metadata_json)
      values (?, ?, ?, ?, ?, ?, ?)
    `,
  );

  for (const node of graph.nodes) {
    insertNode.run(node.id, projectId, node.label, node.type, node.filePath, node.symbolName, JSON.stringify(node.metadata));
  }
  for (const edge of graph.edges) {
    insertEdge.run(edge.id, projectId, edge.source, edge.target, edge.type, edge.heuristic ? 1 : 0, JSON.stringify(edge.metadata));
  }
}

function upsertProject(
  db: DatabaseSync,
  projectId: string,
  name: string,
  repoPath: string,
  status: string,
  createdAt: string,
  indexedAt: string | null,
): void {
  db.prepare(
    `
      insert into projects (project_id, name, repo_path, status, created_at, updated_at, indexed_at)
      values (?, ?, ?, ?, ?, ?, ?)
      on conflict(project_id) do update set
        name = excluded.name,
        repo_path = excluded.repo_path,
        status = excluded.status,
        updated_at = excluded.updated_at,
        indexed_at = excluded.indexed_at
    `,
  ).run(projectId, name, repoPath, status, createdAt, nowIso(), indexedAt);
}

function readProjectSummary(db: DatabaseSync, projectId: string): ProjectSummary | null {
  const projectRow = db
    .prepare(
      `
        select project_id, name, repo_path, status, indexed_at
        from projects
        where project_id = ?
        limit 1
      `,
    )
    .get(projectId) as
    | {
        project_id: string;
        name: string;
        repo_path: string;
        status: ProjectSummary["status"];
        indexed_at: string | null;
      }
    | undefined;

  if (!projectRow) {
    return null;
  }

  const fileCount = scalarCount(db, "select count(*) as count from files where project_id = ?", projectId);
  const symbolCount = scalarCount(db, "select count(*) as count from symbols where project_id = ?", projectId);
  const routeCount = scalarCount(db, "select count(*) as count from spring_routes where project_id = ?", projectId);
  const componentCount = scalarCount(db, "select count(*) as count from vue_components where project_id = ?", projectId);
  const warningRow = db
    .prepare(
      `
        select warnings_json
        from index_runs
        where project_id = ?
        order by started_at desc
        limit 1
      `,
    )
    .get(projectId) as { warnings_json: string } | undefined;

  return {
    projectId: projectRow.project_id,
    name: projectRow.name,
    repoPath: projectRow.repo_path,
    status: projectRow.status,
    indexedAt: projectRow.indexed_at,
    stats: {
      files: fileCount,
      symbols: symbolCount,
      routes: routeCount,
      components: componentCount,
    },
    warnings: warningRow ? (JSON.parse(warningRow.warnings_json) as IndexWarning[]) : [],
  };
}

function scalarCount(db: DatabaseSync, sql: string, projectId: string): number {
  const row = db.prepare(sql).get(projectId) as { count: number } | undefined;
  return row?.count ?? 0;
}

function readdirSyncCompat(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true })
    .filter((entry: { isDirectory(): boolean; name: string }) => entry.isDirectory())
    .map((entry: { name: string }) => entry.name);
}
