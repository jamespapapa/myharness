import type { DatabaseSync } from "node:sqlite";

import type { GraphEdge, GraphNode, IndexedFileArtifact } from "../../shared/src/index.js";

interface BuildOntologyInput {
  projectId: string;
  projectName: string;
  files: IndexedFileArtifact[];
}

interface PersistedGraphRow {
  id: string;
  label: string;
  type: string;
  filePath: string | null;
  symbolName: string | null;
  metadata: Record<string, string | number | boolean | null>;
}

interface PersistedGraphEdgeRow {
  id: string;
  source: string;
  target: string;
  type: string;
  heuristic: boolean;
  metadata: Record<string, string | number | boolean | null>;
}

export function buildOntology(input: BuildOntologyInput): { nodes: PersistedGraphRow[]; edges: PersistedGraphEdgeRow[] } {
  const { projectId, projectName, files } = input;
  const nodeMap = new Map<string, PersistedGraphRow>();
  const edgeMap = new Map<string, PersistedGraphEdgeRow>();

  const addNode = (node: PersistedGraphRow): void => {
    nodeMap.set(node.id, node);
  };

  const addEdge = (edge: PersistedGraphEdgeRow): void => {
    edgeMap.set(edge.id, edge);
  };

  const projectNodeId = `project:${projectId}`;
  addNode({
    id: projectNodeId,
    label: projectName,
    type: "Project",
    filePath: null,
    symbolName: null,
    metadata: {},
  });

  for (const file of files) {
    const moduleName = file.relativePath.includes("/") ? file.relativePath.split("/")[0]! : "(root)";
    const moduleNodeId = `module:${projectId}:${moduleName}`;
    addNode({
      id: moduleNodeId,
      label: moduleName,
      type: "Module",
      filePath: null,
      symbolName: null,
      metadata: {},
    });
    addEdge({
      id: `${projectNodeId}->${moduleNodeId}:contains`,
      source: projectNodeId,
      target: moduleNodeId,
      type: "contains",
      heuristic: false,
      metadata: {},
    });

    const fileNodeId = `file:${projectId}:${file.relativePath}`;
    addNode({
      id: fileNodeId,
      label: file.relativePath,
      type: "File",
      filePath: file.relativePath,
      symbolName: null,
      metadata: {
        language: file.language,
        score: Number(file.repoScore.toFixed(2)),
      },
    });
    addEdge({
      id: `${moduleNodeId}->${fileNodeId}:contains`,
      source: moduleNodeId,
      target: fileNodeId,
      type: "contains",
      heuristic: false,
      metadata: {},
    });

    if (file.componentName) {
      const componentId = `vue:${projectId}:${file.relativePath}:${file.componentName}`;
      addNode({
        id: componentId,
        label: file.componentName,
        type: "VueComponent",
        filePath: file.relativePath,
        symbolName: file.componentName,
        metadata: {},
      });
      addEdge({
        id: `${fileNodeId}->${componentId}:defines`,
        source: fileNodeId,
        target: componentId,
        type: "defines",
        heuristic: true,
        metadata: {},
      });
    }

    for (const symbol of file.symbols) {
      const nodeType = normalizeSymbolType(symbol.symbolType);
      const symbolNodeId = `symbol:${projectId}:${file.relativePath}:${symbol.symbolName}:${symbol.lineStart}`;
      addNode({
        id: symbolNodeId,
        label: symbol.symbolName,
        type: nodeType,
        filePath: symbol.filePath,
        symbolName: symbol.symbolName,
        metadata: {
          lineStart: symbol.lineStart,
          lineEnd: symbol.lineEnd,
          heuristic: symbol.heuristic,
        },
      });
      addEdge({
        id: `${fileNodeId}->${symbolNodeId}:defines`,
        source: fileNodeId,
        target: symbolNodeId,
        type: "defines",
        heuristic: symbol.heuristic,
        metadata: {},
      });
    }

    for (const route of file.routes) {
      const routeNodeId = `route:${projectId}:${file.relativePath}:${route.route}:${route.lineStart}`;
      addNode({
        id: routeNodeId,
        label: `${route.method} ${route.route}`,
        type: "Route",
        filePath: route.filePath,
        symbolName: route.handlerSymbol,
        metadata: {
          method: route.method,
          lineStart: route.lineStart,
          lineEnd: route.lineEnd,
        },
      });

      const controllerSymbol = route.handlerSymbol
        ? [...nodeMap.values()].find(
            (candidate) =>
              candidate.filePath === route.filePath &&
              candidate.symbolName === route.handlerSymbol &&
              (candidate.type === "SpringController" || candidate.type === "Method"),
          )
        : undefined;

      addEdge({
        id: `${controllerSymbol?.id ?? fileNodeId}->${routeNodeId}:maps_route`,
        source: controllerSymbol?.id ?? fileNodeId,
        target: routeNodeId,
        type: "maps_route",
        heuristic: controllerSymbol == null,
        metadata: {},
      });
    }

    for (const dependency of file.buildDependencies) {
      const dependencyId = `dependency:${projectId}:${dependency.name}`;
      addNode({
        id: dependencyId,
        label: dependency.version ? `${dependency.name}@${dependency.version}` : dependency.name,
        type: "BuildDependency",
        filePath: dependency.filePath,
        symbolName: null,
        metadata: {
          version: dependency.version,
        },
      });
      addEdge({
        id: `${fileNodeId}->${dependencyId}:depends_on`,
        source: fileNodeId,
        target: dependencyId,
        type: "depends_on",
        heuristic: false,
        metadata: {},
      });
    }

    for (const apiCall of file.apiCalls) {
      const apiNodeId = `api:${projectId}:${file.relativePath}:${apiCall.target}:${apiCall.lineStart}`;
      addNode({
        id: apiNodeId,
        label: apiCall.target,
        type: "ApiCall",
        filePath: apiCall.filePath,
        symbolName: null,
        metadata: {
          kind: apiCall.kind,
          lineStart: apiCall.lineStart,
          lineEnd: apiCall.lineEnd,
        },
      });
      addEdge({
        id: `${fileNodeId}->${apiNodeId}:invokes_api`,
        source: fileNodeId,
        target: apiNodeId,
        type: "invokes_api",
        heuristic: true,
        metadata: {},
      });
    }
  }

  return {
    nodes: [...nodeMap.values()],
    edges: [...edgeMap.values()],
  };
}

export function readOntologyGraph(db: DatabaseSync, projectId: string): { nodes: GraphNode[]; edges: GraphEdge[] } {
  const nodeRows = db
    .prepare(
      `
        select node_id, label, node_type, file_path, symbol_name, metadata_json
        from ontology_nodes
        where project_id = ?
        order by node_type, label
      `,
    )
    .all(projectId) as Array<{
    node_id: string;
    label: string;
    node_type: string;
    file_path: string | null;
    symbol_name: string | null;
    metadata_json: string;
  }>;

  const edgeRows = db
    .prepare(
      `
        select edge_id, source_id, target_id, edge_type, heuristic, metadata_json
        from ontology_edges
        where project_id = ?
        order by edge_type, edge_id
      `,
    )
    .all(projectId) as Array<{
    edge_id: string;
    source_id: string;
    target_id: string;
    edge_type: string;
    heuristic: number;
    metadata_json: string;
  }>;

  return {
    nodes: nodeRows.map((row) => ({
      id: row.node_id,
      label: row.label,
      type: row.node_type,
      filePath: row.file_path,
      symbolName: row.symbol_name,
      metadata: JSON.parse(row.metadata_json) as GraphNode["metadata"],
    })),
    edges: edgeRows.map((row) => ({
      id: row.edge_id,
      source: row.source_id,
      target: row.target_id,
      type: row.edge_type,
      heuristic: Boolean(row.heuristic),
      metadata: JSON.parse(row.metadata_json) as GraphEdge["metadata"],
    })),
  };
}

function normalizeSymbolType(symbolType: string): string {
  if (symbolType === "SpringController") {
    return "SpringController";
  }
  if (symbolType === "Service") {
    return "Service";
  }
  if (symbolType === "Repository") {
    return "Repository";
  }
  if (symbolType === "Entity") {
    return "Entity";
  }
  if (symbolType === "Interface") {
    return "Interface";
  }
  if (symbolType === "Class") {
    return "Class";
  }
  if (symbolType === "Method" || symbolType === "Function") {
    return "Method";
  }
  return symbolType;
}

