import type { DatabaseSync } from "node:sqlite";

import type { SearchHit, SearchResult } from "../../shared/src/index.js";
import { trimExcerpt } from "../../shared/src/index.js";

export function searchProject(db: DatabaseSync, projectId: string, query: string, limit = 8): SearchResult {
  const ftsQuery = buildFtsQuery(query);
  const exactHits = findExactHits(db, projectId, query, limit);
  const lexicalHits = ftsQuery ? findLexicalHits(db, projectId, ftsQuery, limit) : [];
  const hits = dedupeHits([...exactHits, ...lexicalHits]).slice(0, limit);
  const strongSignalBypass = exactHits.length > 0 || hits.length >= 3;

  return {
    hits,
    strategy: "lexical-mvp",
    strongSignalBypass,
    ftsQuery,
  };
}

function buildFtsQuery(query: string): string {
  const tokens = (query.toLowerCase().match(/[a-z][a-z0-9_]{1,}/g) ?? []).slice(0, 8);
  if (tokens.length === 0) {
    return "";
  }
  return tokens.map((token) => `${token}*`).join(" OR ");
}

function findExactHits(db: DatabaseSync, projectId: string, query: string, limit: number): SearchHit[] {
  const pattern = `%${query.trim().toLowerCase()}%`;
  const symbolRows = db
    .prepare(
      `
        select file_path, line_start, line_end, symbol_name, coalesce(signature, symbol_name) as excerpt
        from symbols
        where project_id = ?
          and lower(symbol_name) like ?
        order by line_start
        limit ?
      `,
    )
    .all(projectId, pattern, Math.max(2, Math.floor(limit / 2))) as Array<{
    file_path: string;
    line_start: number;
    line_end: number;
    symbol_name: string;
    excerpt: string;
  }>;

  const fileRows = db
    .prepare(
      `
        select file_path, 1 as line_start, min(line_count, 40) as line_end, null as symbol_name, file_path as excerpt
        from files
        where project_id = ?
          and lower(file_path) like ?
        order by file_path
        limit ?
      `,
    )
    .all(projectId, pattern, 2) as Array<{
    file_path: string;
    line_start: number;
    line_end: number;
    symbol_name: string | null;
    excerpt: string;
  }>;

  return [...symbolRows, ...fileRows].map((row) => ({
    filePath: row.file_path,
    lineStart: row.line_start,
    lineEnd: row.line_end,
    symbolName: row.symbol_name,
    excerpt: trimExcerpt(row.excerpt),
    score: -100,
    reason: "exact",
  }));
}

function findLexicalHits(db: DatabaseSync, projectId: string, ftsQuery: string, limit: number): SearchHit[] {
  const rows = db
    .prepare(
      `
        select
          file_path,
          line_start,
          line_end,
          symbol_name,
          snippet(fts_documents, 5, '[[', ']]', ' … ', 18) as excerpt,
          bm25(fts_documents) as score
        from fts_documents
        where project_id = ?
          and fts_documents match ?
        order by score
        limit ?
      `,
    )
    .all(projectId, ftsQuery, limit) as Array<{
    file_path: string;
    line_start: number;
    line_end: number;
    symbol_name: string | null;
    excerpt: string;
    score: number;
  }>;

  return rows.map((row) => ({
    filePath: row.file_path,
    lineStart: row.line_start,
    lineEnd: row.line_end,
    symbolName: row.symbol_name,
    excerpt: trimExcerpt(row.excerpt),
    score: row.score,
    reason: "lexical",
  }));
}

function dedupeHits(hits: SearchHit[]): SearchHit[] {
  const seen = new Set<string>();
  return hits.filter((hit) => {
    const key = `${hit.filePath}:${hit.lineStart}:${hit.lineEnd}:${hit.symbolName ?? ""}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

