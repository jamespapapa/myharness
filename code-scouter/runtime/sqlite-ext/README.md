# SQLite Extensions

Store vendored loadable SQLite extensions here.

Phase 1 notes:
- lexical retrieval uses built-in SQLite FTS5 via `node:sqlite`
- vector search is deferred
- the server includes an optional extension-load hook so `sqlite-vec` can be introduced without changing API shape
