import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

import { ChatRequestSchema, type ChatResponse, type Citation } from "../../shared/src/index.js";
import { nowIso, trimExcerpt } from "../../shared/src/index.js";
import { searchProject } from "../../search/src/index.js";

export function answerQuestion(db: DatabaseSync, projectId: string, rawRequest: unknown): ChatResponse {
  const request = ChatRequestSchema.parse(rawRequest);
  const sessionId = ensureSession(db, projectId, request.sessionId, request.question);
  persistMessage(db, sessionId, "user", request.question);

  const searchResult = searchProject(db, projectId, request.question);
  const citations: Citation[] = searchResult.hits.slice(0, 5).map((hit) => ({
    filePath: hit.filePath,
    lineStart: hit.lineStart,
    lineEnd: hit.lineEnd,
    symbolName: hit.symbolName,
    excerpt: trimExcerpt(hit.excerpt, 240),
    reason: hit.reason,
  }));

  const answer = citations.length === 0 ? buildUnknownAnswer(request.question) : buildGroundedAnswer(request.question, citations, searchResult.strongSignalBypass);

  const assistantMessageId = persistMessage(db, sessionId, "assistant", answer);
  db.prepare(
    `
      insert into evidence_sets (evidence_id, message_id, citations_json)
      values (?, ?, ?)
    `,
  ).run(randomUUID(), assistantMessageId, JSON.stringify(citations));

  return {
    sessionId,
    answer,
    citations,
    diagnostics: {
      strategy: searchResult.strategy,
      strongSignalBypass: searchResult.strongSignalBypass,
      ftsQuery: searchResult.ftsQuery,
    },
  };
}

function ensureSession(db: DatabaseSync, projectId: string, sessionId: string | undefined, question: string): string {
  const id = sessionId ?? randomUUID();
  const existing = db
    .prepare("select session_id from chat_sessions where session_id = ? and project_id = ? limit 1")
    .get(id, projectId) as { session_id: string } | undefined;

  if (!existing) {
    db.prepare(
      `
        insert into chat_sessions (session_id, project_id, title, created_at, updated_at)
        values (?, ?, ?, ?, ?)
      `,
    ).run(id, projectId, question.slice(0, 80), nowIso(), nowIso());
  } else {
    db.prepare("update chat_sessions set updated_at = ? where session_id = ?").run(nowIso(), id);
  }

  return id;
}

function persistMessage(db: DatabaseSync, sessionId: string, role: "user" | "assistant", content: string): string {
  const messageId = randomUUID();
  db.prepare(
    `
      insert into chat_messages (message_id, session_id, role, content, created_at)
      values (?, ?, ?, ?, ?)
    `,
  ).run(messageId, sessionId, role, content, nowIso());
  db.prepare("update chat_sessions set updated_at = ? where session_id = ?").run(nowIso(), sessionId);
  return messageId;
}

function buildUnknownAnswer(question: string): string {
  return [
    `Unknown based on the current index for "${question}".`,
    "I could not find grounded lexical evidence in the indexed repository yet.",
    "Reindex the project if files changed, or narrow the question toward a symbol, path, or route.",
  ].join("\n");
}

function buildGroundedAnswer(question: string, citations: Citation[], strongSignalBypass: boolean): string {
  const evidenceLines = citations.slice(0, 3).map((citation) => {
    const symbol = citation.symbolName ? ` (${citation.symbolName})` : "";
    return `- ${citation.filePath}:${citation.lineStart}-${citation.lineEnd}${symbol} — ${trimExcerpt(citation.excerpt, 180)}`;
  });

  return [
    `Observed local evidence for "${question}":`,
    ...evidenceLines,
    strongSignalBypass
      ? "Lexical evidence was already strong, so expansion and reranking were skipped."
      : "This Phase 1 skeleton is returning the strongest lexical evidence without expansion or reranking.",
  ].join("\n");
}
