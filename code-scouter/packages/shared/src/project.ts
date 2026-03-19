import { createHash } from "node:crypto";
import path from "node:path";

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48) || "project";
}

export function basenameLabel(repoPath: string): string {
  return path.basename(repoPath) || "project";
}

export function createProjectId(repoPath: string, projectName?: string): string {
  const base = slugify(projectName ?? basenameLabel(repoPath));
  const hash = createHash("sha256").update(repoPath).digest("hex").slice(0, 10);
  return `${base}-${hash}`;
}

export function sha256(content: string | Buffer): string {
  return createHash("sha256").update(content).digest("hex");
}

export function nowIso(): string {
  return new Date().toISOString();
}

