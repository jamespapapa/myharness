# Phase 1 Handoff

## Status

Phase 1 is complete and intentionally frozen. This repository now has a working local-first baseline for indexing, grounded chat, Monaco file viewing, and ontology graph browsing. Do not start Phase 2 work from memory; use this document as the restart point.

## What Exists Now

### Server

- Local Node HTTP API in `apps/server/src/index.ts`
- Health, project listing, indexing, chat, graph, file-content, and patch-preview endpoints
- Per-project SQLite database stored at `data/<project-id>/project.db`
- Built on Node 24 `node:sqlite` with FTS5

### Web UI

- React/Vite control UI in `apps/web`
- Index tab for repository path submission and project stats
- Chat tab with grounded citations
- Monaco editor pane with patch preview
- Graph tab with Cytoscape rendering and node detail/open-in-editor flow

### Packages

- `packages/shared`: schemas, project ID helpers, SQLite helpers, text helpers
- `packages/indexer`: scan, extraction stubs, schema init, persistence, graph/file access
- `packages/search`: lexical FTS retrieval
- `packages/ontology`: node/edge materialization and graph reads
- `packages/chat`: grounded answer orchestration and chat session persistence

### Benchmark / Regression Fixture

- Stable fixture repo: `test/fixtures/phase1-benchmark/`
- Intended use: hold a small Java/Spring + Vue corpus constant across future Phase 2 retrieval changes

## How To Run

### Install

```bash
npm install
```

### Server

```bash
npm run dev:server
```

Default URL: `http://localhost:4312`

### Web

```bash
npm run dev:web
```

Default Vite URL: `http://localhost:4173`

### Production Web Build

```bash
npm run build:web
```

## How To Index A Repo

### From the UI

1. Start server and web.
2. Open the web UI.
3. Go to the `Index` tab.
4. Enter a local repository path.
5. Optionally enter a display name.
6. Press `Start Index`.
7. Wait for project stats to populate, then use `Chat` or `Graph`.

### From the API

```bash
curl -X POST http://localhost:4312/api/projects/index \
  -H "content-type: application/json" \
  -d '{"repoPath":"C:\\repos\\sample-app","projectName":"Sample App"}'
```

## Available APIs

### `GET /api/health`

- Returns server health plus whether the built web assets are present.

### `GET /api/projects`

- Lists indexed projects discovered under `data/`.

### `POST /api/projects/index`

- Starts first-time indexing for a local repository path.
- Request body:

```json
{
  "repoPath": "C:\\repos\\sample-app",
  "projectName": "Sample App"
}
```

### `GET /api/projects/:projectId`

- Returns a single project summary and current stats.

### `POST /api/projects/:projectId/chat`

- Runs grounded repository chat against the indexed project.
- Request body:

```json
{
  "question": "Where is /healthz mapped?",
  "sessionId": "optional-existing-session-id"
}
```

### `GET /api/projects/:projectId/graph`

- Returns ontology nodes and edges for Cytoscape.

### `GET /api/projects/:projectId/files/content?path=<relative-path>`

- Returns indexed file content for Monaco.

### `POST /api/projects/:projectId/patch-preview`

- Returns a synthetic unified diff against the indexed file content.

## Validation Commands

These commands passed at handoff time:

```bash
npm run typecheck
npm test
npm run smoke:index
npm run build:web
```

`npm test` currently includes:

- health endpoint coverage
- indexing coverage
- grounded chat citation coverage
- graph endpoint coverage
- file-content endpoint coverage

## Current Limitations

- `node:sqlite` prints an experimental warning on Node 24. This is expected in Phase 1 and documented, not yet removed.
- Retrieval is lexical-first only. `sqlite-vec`, RRF, local query expansion, and reranking are deferred.
- Extraction is intentionally shallow for Phase 1 and depends on regex/tree-sitter hybrids rather than deep framework coverage.
- Chat synthesis is template-driven and grounded, but not yet a strong retrieval planner.
- Monaco causes a large production bundle. This is a known follow-up, not a Phase 1 blocker.
- The current benchmark fixture is intentionally small and should be treated as a regression anchor, not an evaluation harness.

## Recommended Next Tasks

Priority order:

1. Phase 2 hybrid retrieval activation: wire `sqlite-vec`, vector writes, and vector reads without changing Phase 1 APIs.
2. Add reciprocal rank fusion between lexical and vector results, keeping a strong-signal lexical bypass.
3. Add a stable retrieval comparison flow against `test/fixtures/phase1-benchmark/` before broader dataset work.
4. Add bounded local query expansion and reranking hooks behind feature flags or clear module seams.
5. Reduce Monaco bundle size after retrieval behavior is stable.

## Guardrails For The Next Session

- Do not expand architecture surface before Phase 2 retrieval is working against the current APIs.
- Keep the benchmark fixture stable so output comparisons remain meaningful.
- Do not swap away from SQLite or add external services.
- Treat this handoff as the authoritative Phase 1 baseline.

