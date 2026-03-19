# System Architecture

## Goal

Build an offline-first repository analysis product for large Java/Spring + Vue repositories that works in Windows closed-network environments with small local LLMs.

The product must let users:
1. index a local repository once
2. chat against the indexed project
3. open referenced code in a Monaco-based editor
4. browse an ontology graph immediately after indexing

The model is not the source of truth for repository structure. The model is the last-mile synthesizer.

---

## Product Shape

### Control UI

The web UI has three primary workspaces.

#### 1. Index
- select local repository path
- create project entry
- start first-time indexing
- reindex changed files later
- see progress, stats, warnings, failures

#### 2. Chat
- ChatGPT-like conversation UX
- answers grounded with file/line evidence
- referenced code opens in Monaco
- editor supports viewing and local edits
- patch preview can be shown before saving

#### 3. Graph
- ontology graph viewer rendered immediately after indexing
- filters by node type, edge type, path prefix, and hop depth
- clicking a node shows details, evidence, and linked code

---

## Runtime Constraints

- Windows closed-network deployment
- Node.js-first runtime
- SQLite as the only database
- vendored models and native assets allowed
- no cloud services in critical path
- no separate Go / Java / Python / Docker runtime assumptions for end users

### Phase 1 Implementation Notes

- The current skeleton uses Node 24's built-in `node:sqlite` module with FTS5 enabled.
- Node 24 currently prints an experimental warning for `node:sqlite`; this is expected in the present Phase 1 baseline.
- `runtime/sqlite-ext/` is reserved for loadable extensions such as `sqlite-vec`; Phase 1 keeps the load hook but does not run live vector search yet.
- The server is a local Node HTTP API in `apps/server`.
- The web control UI is a React/Vite app in `apps/web` with Monaco and Cytoscape wired to the local API.
- Monaco currently contributes a large client bundle; bundle splitting is a follow-up task, not part of the Phase 1 freeze.

---

## Monorepo Layout

apps/
  server/
  web/
packages/
  shared/
  indexer/
  search/
  ontology/
  chat/
  ui-contracts/
runtime/
  models/
  sqlite-ext/
third_party/
data/
  <project-id>/
    project.db

---

## Subsystems

### 1. apps/server
Responsibilities:
- project lifecycle APIs
- indexing orchestration
- retrieval APIs
- chat orchestration APIs
- graph query APIs
- file content and patch APIs

### 2. apps/web
Responsibilities:
- Index page
- Chat page
- Monaco-based code viewer/editor
- Graph viewer
- citations, evidence drill-down, patch preview

### 3. packages/indexer
Responsibilities:
- repository scan
- ignore rules
- file hashing
- language detection
- tree-sitter parsing
- ast-grep structural evidence collection
- Java/Spring detectors
- Vue detectors
- repo map generation

### 4. packages/search
Responsibilities:
- SQLite FTS5 lexical retrieval
- sqlite-vec vector retrieval
- reciprocal rank fusion
- optional query expansion
- optional reranking
- context packing

### 5. packages/ontology
Responsibilities:
- node/edge materialization
- graph validation
- graph query helpers
- graph projections for UI

### 6. packages/chat
Responsibilities:
- session/task ledger
- intent classification
- retrieval planning
- bounded summarization
- grounded answer synthesis

### 7. packages/shared
Responsibilities:
- schemas
- DTOs
- common logging
- config loading
- SQLite helpers

---

## Core Data Flow

### A. First-Time Indexing
1. scan repository
2. respect ignore rules
3. hash files
4. parse supported files
5. detect framework structures
6. extract symbols and relations
7. generate repo map
8. write metadata and ontology to SQLite
9. build lexical/vector search artifacts
10. build cards for repo/module/file/symbol
11. mark project ready

### B. Chat / Analysis
1. user asks question
2. extract anchors from the question
3. consult repo map and exact symbol/path matches
4. run lexical retrieval
5. expand through ontology graph as needed
6. optionally run vector retrieval and reranking
7. pack cards + small evidence spans
8. synthesize grounded answer
9. return answer + evidence + graph/file links

Phase 1 behavior:
- lexical retrieval is implemented
- vector retrieval tables and extension hooks exist but are not active yet
- grounded synthesis is template-driven and file/line cited

### C. Graph Browsing
1. load graph projection from SQLite
2. filter nodes/edges server-side
3. render in Cytoscape
4. clicking node fetches details and linked evidence

---

## SQLite Schema Families

### projects
- projects
- project_settings
- index_runs
- scan_files

### code structure
- files
- symbols
- symbol_signatures
- imports
- references
- calls
- inheritance
- injections
- build_dependencies

### framework-specific
- spring_routes
- api_calls
- vue_components
- vue_component_uses
- config_keys
- sql_queries
- sql_bindings
- db_tables
- db_columns
- test_cases
- test_links

### ontology
- ontology_nodes
- ontology_edges

### summaries / cards
- repo_cards
- module_cards
- file_cards
- symbol_cards

### retrieval
- fts_documents
- fts_chunks
- vec_chunks
- retrieval_cache

### chat memory
- chat_sessions
- chat_messages
- task_ledgers
- evidence_sets

---

## Minimum Practical Ontology

### Node Types
- Project
- Module
- File
- JavaPackage
- Class
- Interface
- Method
- Field
- SpringController
- Route
- Service
- Repository
- Entity
- DTO
- ConfigKey
- SqlQuery
- Table
- Column
- VueComponent
- VueProp
- VueEmit
- FrontRoute
- ApiClient
- ApiCall
- BuildDependency
- TestCase

### Edge Types
- contains
- imports
- depends_on
- defines
- extends
- implements
- injects
- calls
- maps_route
- handled_by
- returns_dto
- reads_config
- invokes_api
- uses_component
- emits_event
- reads_table
- writes_table
- executes_query
- binds_param
- tested_by

The ontology is practical, not academic.
Each node/edge type must improve at least one of:
- navigation
- impact analysis
- API tracing
- DB tracing
- frontend-backend linkage

---

## Extraction Targets

### Java / Spring
- `@Controller`, `@RestController`
- `@RequestMapping`, `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`
- `@Service`, `@Repository`, `@Component`
- constructor injection and `@Autowired`
- JPA entities and repositories
- `@Query`
- `JdbcTemplate`, `NamedParameterJdbcTemplate`
- MyBatis mapper interfaces and XML
- Maven `pom.xml`
- Gradle build files

### Vue 2 / 3
- `.vue` SFC structure
- component imports and registrations
- `props`, `emits`, `computed`, `methods`
- Vue Router
- `axios`, `fetch`, `$http`, `$axios` calls
- optional store linkage if extraction is cheap

---

## Repo Map

Use an Aider-style repo map as the top-level “terrain map”.

The repo map contains concise entries for important files, classes, interfaces, methods, and route handlers.
Each entry should include:
- path
- symbol kind
- name
- signature summary
- relation score
- relevance hints

The repo map is used before raw code retrieval.
It is the first high-level context presented to the planner and synthesis stages.

---

## Retrieval Strategy

Default retrieval order:
1. repo map / exact anchor lookup
2. lexical retrieval (FTS5)
3. ontology expansion
4. vector retrieval (sqlite-vec)
5. query expansion / reranking when justified

### Strong-signal bypass
If lexical retrieval is already strong enough, skip expensive model-assisted expansion/reranking.

### Merge policy
Use reciprocal rank fusion to combine lexical and vector retrieval.

### Context packing
Prefer:
- repo/module/file/symbol cards
- small evidence spans
- route/query/table/component metadata

Avoid full-file prompts by default.

---

## Cards and Evidence

### Repo card
- system purpose
- major modules
- key entry points
- primary frameworks
- known gaps

### Module card
- responsibility
- owned paths
- key symbols
- inbound/outbound dependencies
- routes / APIs / tables

### File card
- purpose
- important symbols
- side effects
- routes/configs/queries/tests

### Symbol card
- role
- callers/callees
- dto/config/query/table links
- caveats

### Evidence span
Always include:
- file path
- line range
- symbol name when available
- reason for inclusion

---

## Model Usage Rules

Use the local model only for:
- bounded summarization
- retrieval planning
- final grounded synthesis

Do not use the model to discover repository structure from scratch.
Do not rely on chat history as the only memory.
Persist session/task state in SQLite.

---

## UI Contract Summary

### Index page
- create project
- choose repo path
- start / resume indexing
- show per-stage progress
- show counts: files, symbols, routes, queries, graph nodes/edges

### Chat page
- threaded conversation
- citations to file and line
- open in editor
- patch preview
- session history

### Graph page
- graph viewer
- node/edge filtering
- search/highlight
- details panel
- “open code” links

---

## Phase Plan

### Phase 1
- monorepo skeleton
- SQLite schema
- project scan
- tree-sitter parsers
- ast-grep integration
- repo map MVP
- lexical retrieval MVP
- basic grounded chat API
- Monaco viewer integration
- Cytoscape graph MVP

### Phase 2
- qmd-style vector retrieval + RRF
- local query expansion and reranking
- ontology enrichment
- impact analysis
- flow tracing
- patch workflow

### Phase 3
- stronger ranking
- snapshot/export mode
- evaluation harness
- incremental reindex optimization

---

## Definition of Done

The product is ready for first internal use when:
- a repository can be indexed once and queried afterward
- answers are grounded with file/line evidence
- referenced code opens in Monaco
- the graph viewer shows ontology immediately after indexing
- the product runs on Windows closed-network machines using only vendored runtime assets
