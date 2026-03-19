# Active Plan

## Status

Phase 1 is implemented and frozen for stabilization handoff. This plan now serves as the current execution snapshot for the next fresh Codex session.

## Completed Phase 1 Scope

- Runnable local Node HTTP server in `apps/server`
- Runnable React/Vite web control UI in `apps/web`
- Local SQLite project database per indexed repository using `node:sqlite`
- First-time repository scan and indexing pipeline
- Deterministic extraction stubs for Java/Spring and Vue
- Repo-map cards, lexical FTS indexing, and ontology graph materialization
- Grounded chat responses with file/line citations
- Monaco-based file viewing and patch preview
- Cytoscape graph viewing
- Phase 1 benchmark fixture plus package/server smoke coverage

## Validation Commands That Passed

- `npm run typecheck`
- `npm test`
- `npm run smoke:index`
- `npm run build:web`

`npm test` now covers:
- API health
- indexing
- grounded chat citations
- graph API
- file-content API

## Known Risks

- `node:sqlite` still emits Node's experimental warning on Node 24 even though Phase 1 behavior is working.
- Retrieval is lexical-first only; `sqlite-vec`, RRF, expansion, and reranking are not active yet.
- Java/Vue extraction remains intentionally partial and uses regex/tree-sitter hybrids with graceful degradation.
- Monaco currently dominates the web production bundle size; code-splitting/manual chunking is deferred.
- Chat synthesis is template-driven for Phase 1 and should not be mistaken for final retrieval quality.

## Benchmark / Regression Anchor

- Stable fixture: `test/fixtures/phase1-benchmark/`
- Stable smoke script: `npm run smoke:index`
- Stable HTTP integration coverage: `apps/server/src/index.test.ts`

## Explicit Next Milestone

Phase 2 hybrid retrieval only:

1. activate local vector retrieval with `sqlite-vec`
2. add reciprocal rank fusion for lexical + vector results
3. add bounded local query expansion and reranking hooks
4. compare Phase 2 retrieval quality against the Phase 1 benchmark fixture before expanding scope

