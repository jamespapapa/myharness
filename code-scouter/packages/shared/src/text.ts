export interface TextChunk {
  text: string;
  lineStart: number;
  lineEnd: number;
}

export function splitLines(content: string): string[] {
  return content.split(/\r?\n/);
}

export function buildLineStarts(content: string): number[] {
  const starts = [0];
  for (let index = 0; index < content.length; index += 1) {
    if (content[index] === "\n") {
      starts.push(index + 1);
    }
  }
  return starts;
}

export function lineNumberFromOffset(lineStarts: number[], offset: number): number {
  let low = 0;
  let high = lineStarts.length - 1;

  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const start = lineStarts[middle]!;
    const next = lineStarts[middle + 1] ?? Number.POSITIVE_INFINITY;
    if (offset >= start && offset < next) {
      return middle + 1;
    }
    if (offset < start) {
      high = middle - 1;
    } else {
      low = middle + 1;
    }
  }

  return lineStarts.length;
}

export function excerptByLineRange(content: string, lineStart: number, lineEnd: number): string {
  const lines = splitLines(content);
  return lines.slice(lineStart - 1, lineEnd).join("\n");
}

export function chunkText(content: string, windowSize = 24, overlap = 6): TextChunk[] {
  const lines = splitLines(content);
  if (lines.length === 0) {
    return [];
  }

  const chunks: TextChunk[] = [];
  let cursor = 0;
  while (cursor < lines.length) {
    const start = cursor;
    const end = Math.min(lines.length, cursor + windowSize);
    chunks.push({
      text: lines.slice(start, end).join("\n"),
      lineStart: start + 1,
      lineEnd: end,
    });
    if (end === lines.length) {
      break;
    }
    cursor = Math.max(start + 1, end - overlap);
  }
  return chunks;
}

export function trimExcerpt(text: string, limit = 220): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return `${normalized.slice(0, limit - 1)}…`;
}

export function buildPatchPreview(originalContent: string, updatedContent: string, filePath: string): string {
  if (originalContent === updatedContent) {
    return `No changes for ${filePath}`;
  }

  const originalLines = splitLines(originalContent);
  const updatedLines = splitLines(updatedContent);

  let prefix = 0;
  while (
    prefix < originalLines.length &&
    prefix < updatedLines.length &&
    originalLines[prefix] === updatedLines[prefix]
  ) {
    prefix += 1;
  }

  let suffix = 0;
  while (
    suffix < originalLines.length - prefix &&
    suffix < updatedLines.length - prefix &&
    originalLines[originalLines.length - 1 - suffix] === updatedLines[updatedLines.length - 1 - suffix]
  ) {
    suffix += 1;
  }

  const originalChanged = originalLines.slice(prefix, originalLines.length - suffix);
  const updatedChanged = updatedLines.slice(prefix, updatedLines.length - suffix);

  const header = [
    `--- a/${filePath}`,
    `+++ b/${filePath}`,
    `@@ -${prefix + 1},${originalChanged.length} +${prefix + 1},${updatedChanged.length} @@`,
  ];

  const removed = originalChanged.map((line) => `-${line}`);
  const added = updatedChanged.map((line) => `+${line}`);
  return [...header, ...removed, ...added].join("\n");
}
