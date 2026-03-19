import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "../../../");

export function getRepoRoot(): string {
  return repoRoot;
}

export function resolveDataRoot(): string {
  return path.join(repoRoot, "data");
}

export function resolveProjectDataDir(projectId: string): string {
  return path.join(resolveDataRoot(), projectId);
}

export function resolveProjectDbPath(projectId: string): string {
  return path.join(resolveProjectDataDir(projectId), "project.db");
}

export function resolveRuntimeSqliteExtDir(): string {
  return path.join(repoRoot, "runtime", "sqlite-ext");
}

