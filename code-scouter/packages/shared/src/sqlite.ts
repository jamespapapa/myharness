import { DatabaseSync } from "node:sqlite";
import { existsSync, mkdirSync, readdirSync } from "node:fs";
import path from "node:path";

import { resolveProjectDataDir, resolveProjectDbPath, resolveRuntimeSqliteExtDir } from "./paths.js";

export interface OpenProjectDatabaseOptions {
  projectId: string;
  readOnly?: boolean;
}

export function openProjectDatabase(options: OpenProjectDatabaseOptions): DatabaseSync {
  const { projectId, readOnly = false } = options;
  const projectDir = resolveProjectDataDir(projectId);
  if (!readOnly) {
    mkdirSync(projectDir, { recursive: true });
  }

  const databasePath = resolveProjectDbPath(projectId);
  const db = new DatabaseSync(databasePath, { open: true, readOnly });
  db.exec("pragma foreign_keys = on;");
  db.exec("pragma journal_mode = wal;");

  maybeLoadSqliteExtensions(db);
  return db;
}

export function withTransaction<T>(db: DatabaseSync, work: () => T): T {
  db.exec("begin immediate transaction;");
  try {
    const result = work();
    db.exec("commit;");
    return result;
  } catch (error) {
    db.exec("rollback;");
    throw error;
  }
}

function maybeLoadSqliteExtensions(db: DatabaseSync): void {
  const extensionDir = resolveRuntimeSqliteExtDir();
  if (!existsSync(extensionDir)) {
    return;
  }

  const configuredPath = process.env.CODE_SCOUTER_SQLITE_EXT_PATH;
  const candidatePaths = configuredPath
    ? [configuredPath]
    : readdirSync(extensionDir)
        .filter((entry) => entry.toLowerCase().endsWith(".dll") || entry.toLowerCase().endsWith(".dylib") || entry.toLowerCase().endsWith(".so"))
        .map((entry) => path.join(extensionDir, entry));

  if (candidatePaths.length === 0) {
    return;
  }

  db.enableLoadExtension(true);
  try {
    for (const extensionPath of candidatePaths) {
      db.loadExtension(extensionPath);
    }
  } catch {
    // Phase 1 uses FTS5 only. Missing or incompatible extensions should not block the app.
  } finally {
    db.enableLoadExtension(false);
  }
}

