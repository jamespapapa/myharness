# Phase 1 Bootstrap Plan

## Requirements Summary

- Build a Node/TypeScript monorepo skeleton with `apps/server`, `apps/web`, and `packages/*`.
- Keep runtime local-only: Node.js, vendored dependencies, local SQLite DB, vendored model and extension assets.
- Provide first-time indexing, grounded chat, Monaco code viewing, and graph browsing.
- Prefer end-to-end wiring over deep extraction completeness.

## Acceptance Criteria

- `POST /api/projects/index` indexes a local repository into `data/<project-id>/project.db`.
- `POST /api/projects/:id/chat` returns grounded citations with file path and line range.
- `GET /api/projects/:id/files/content` returns source content for Monaco.
- `GET /api/projects/:id/graph` returns ontology nodes and edges for Cytoscape.
- Web UI exposes Index, Chat, and Graph tabs with a shared project selector and editor panel.

## Implementation Steps

1. Create repo-level package/tooling files and planning artifacts.
2. Add shared TypeScript schemas, project ID helpers, and SQLite opening/schema helpers.
3. Implement indexer scan, chunking, extraction stubs, repo-map ranking, and ontology persistence.
4. Implement search and chat packages on top of SQLite FTS5 with grounded synthesis.
5. Implement an HTTP server with JSON APIs for project listing, indexing, chat, graph, and file access.
6. Implement a React/Vite UI with Monaco editor, chat citations, and Cytoscape rendering.
7. Run install, tests, typecheck, and smoke indexing.

## Risks and Mitigations

- Experimental `node:sqlite`: isolate DB access behind shared helpers so the binding can be swapped later.
- Parser gaps on Vue/Spring edge cases: mark uncertain extraction as heuristic and keep raw file chunks searchable.
- Offline/runtime drift: avoid non-Node runtime dependencies and keep extension/model assets declarative under `runtime/`.

## Verification

- `npm install`
- `npm run test`
- `npm run typecheck`
- `npm run build:web`
- `npm run smoke:index`

