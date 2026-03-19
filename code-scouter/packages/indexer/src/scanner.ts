import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";

import { sha256, splitLines, type IndexWarning, type LanguageKind, type ScannedSourceFile } from "../../shared/src/index.js";

const IGNORED_DIRS = new Set([
  ".git",
  ".idea",
  ".vscode",
  "node_modules",
  "dist",
  "build",
  "coverage",
  "data",
  ".agent",
  ".omx",
]);

const BINARY_EXTENSIONS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".zip",
  ".jar",
  ".war",
  ".class",
  ".pdf",
  ".dll",
  ".so",
  ".dylib",
  ".exe",
]);

export async function scanRepository(repoPath: string): Promise<{ files: ScannedSourceFile[]; warnings: IndexWarning[] }> {
  const files: ScannedSourceFile[] = [];
  const warnings: IndexWarning[] = [];
  await walk(repoPath, repoPath, files, warnings);
  files.sort((left, right) => left.relativePath.localeCompare(right.relativePath));
  return { files, warnings };
}

async function walk(
  rootPath: string,
  currentPath: string,
  files: ScannedSourceFile[],
  warnings: IndexWarning[],
): Promise<void> {
  const entries = await readdir(currentPath, { withFileTypes: true });

  for (const entry of entries) {
    const absolutePath = path.join(currentPath, entry.name);
    if (entry.isDirectory()) {
      if (!IGNORED_DIRS.has(entry.name)) {
        await walk(rootPath, absolutePath, files, warnings);
      }
      continue;
    }

    if (!entry.isFile()) {
      continue;
    }

    const extension = path.extname(entry.name).toLowerCase();
    if (BINARY_EXTENSIONS.has(extension)) {
      continue;
    }

    const fileStat = await stat(absolutePath);
    if (fileStat.size > 512_000) {
      warnings.push({
        code: "scan.file_skipped_too_large",
        message: `Skipped ${absolutePath} because it exceeds the 512KB Phase 1 scan limit.`,
      });
      continue;
    }

    const buffer = await readFile(absolutePath);
    if (buffer.includes(0)) {
      continue;
    }

    const content = buffer.toString("utf8");
    const relativePath = toPosix(path.relative(rootPath, absolutePath));
    files.push({
      absolutePath,
      relativePath,
      language: inferLanguage(relativePath),
      size: fileStat.size,
      sha256: sha256(buffer),
      content,
      lineCount: splitLines(content).length,
    });
  }
}

function inferLanguage(filePath: string): LanguageKind {
  const extension = path.extname(filePath).toLowerCase();
  if (filePath.endsWith("pom.xml") || filePath.endsWith(".xml")) {
    return "xml";
  }
  if (filePath.endsWith(".java")) {
    return "java";
  }
  if (filePath.endsWith(".ts")) {
    return "typescript";
  }
  if (filePath.endsWith(".tsx")) {
    return "tsx";
  }
  if (filePath.endsWith(".js")) {
    return "javascript";
  }
  if (filePath.endsWith(".jsx")) {
    return "jsx";
  }
  if (filePath.endsWith(".vue")) {
    return "vue";
  }
  if (filePath.endsWith(".sql")) {
    return "sql";
  }
  if (filePath.endsWith(".json")) {
    return "json";
  }
  if (filePath.endsWith(".md")) {
    return "markdown";
  }
  if (extension === ".yaml" || extension === ".yml" || extension === ".properties" || extension === ".gradle") {
    return "text";
  }
  return "unknown";
}

function toPosix(value: string): string {
  return value.split(path.sep).join("/");
}

