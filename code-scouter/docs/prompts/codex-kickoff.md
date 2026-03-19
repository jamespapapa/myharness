# Codex Kickoff Prompt

Read these files first:
- `AGENTS.md`
- `docs/architecture/system-architecture.md`
- `docs/operations/vendoring-and-intake.md`
- `.agent/PLANS.md`

We are building an offline-first repository analysis product for Windows closed-network environments.

## Hard Constraints
- Must run with Node.js only in practice: app code + node_modules + vendored model files + local SQLite DB.
- No external services in the critical path.
- No assumption that Bash tools, Go binaries, Java servers, Python environments, or Docker are installed on target machines.
- SQLite is the only database.
- First-time indexing is performed once per project, then the indexed project is used for chat/analysis.
- Web Control UI is required with:
  1) indexing screen
  2) chat interface with ChatGPT-like UX
  3) Monaco-based code viewer/editor
  4) ontology graph viewer

## Dependency Gate
Adopt only if usable inside Node.js or as a vendored npm/native module without separate installation on Windows.
If an upstream project is valuable but fails the gate, borrow the idea only and reimplement the needed subset.

## Upstream Strategy
Use pinned upstream snapshots from the intake manifest.
Do not rely on floating `main` branches.
Do not depend on external CLIs in the runtime path.

## Adopted Runtime Technologies
- qmd concepts and selected source-level internalization for hybrid retrieval
- node-llama-cpp with vendored GGUF models
- tree-sitter + Java / TS / Vue parsers
- @ast-grep/napi
- Monaco Editor
- Cytoscape.js
- SQLite with FTS5 and sqlite-vec extension loading

## Ideas to Borrow, Not Runtime Dependencies
- Aider Repo Map: concise repository map + token-budget-aware selection
- Zoekt: symbol-aware lexical ranking ideas
- OpenGrok: cross-reference browsing UX ideas
- Joern: minimal code-property-graph-style ontology edges
- Repomix: optional context snapshot/export mode

## Primary Architecture
- Node/TypeScript monorepo
- `apps/server`: API server
- `apps/web`: React web UI
- `packages/indexer`: parsing and indexing
- `packages/search`: hybrid retrieval
- `packages/ontology`: graph generation
- `packages/chat`: orchestration
- `packages/shared`: schemas and utilities
- `data/<project-id>/project.db`: SQLite database per indexed project

## Core Product Behavior
1. User selects a local repository
2. System performs first-time indexing
3. System extracts repository structure, symbols, and relationships
4. System builds:
   - repository map
   - lexical search index
   - vector index
   - ontology graph
   - file/symbol/module cards
5. User can chat against the indexed repository
6. User can open referenced code in Monaco editor
7. User can inspect graph nodes and relationships in graph viewer

## Hybrid Retrieval Requirements
- Keep retrieval local and in-process
- Use SQLite FTS5 BM25 for lexical search
- Use sqlite-vec for vector search
- Use Reciprocal Rank Fusion for lexical + vector merge
- Add optional query expansion and reranking using local GGUF models
- Implement strong-signal bypass: if lexical retrieval is already strong, skip expensive expansion/reranking when possible
- Keep all search APIs callable as TypeScript modules, not shell commands

## Repo Map Requirements
- Build a compact repo map of important files, classes, functions, and method signatures
- Rank map entries by practical importance using imports/calls/dependencies/references
- Fit map slices into bounded token budgets
- Prefer map/cards over raw full-file code

## Structural Search Requirements
- Use tree-sitter for primary parsing
- Use ast-grep for targeted structural evidence collection and framework-specific pattern searches
- Support Java/Spring and Vue 2/3 as first-class targets

## Minimal Practical Ontology
Nodes:
- Project, Module, File, JavaPackage, Class, Interface, Method, Field
- SpringController, Route, Service, Repository, Entity, DTO, ConfigKey
- SqlQuery, Table, Column
- VueComponent, VueProp, VueEmit, FrontRoute, ApiClient, ApiCall
- BuildDependency, TestCase

Edges:
- contains, imports, depends_on, defines, extends, implements
- injects, calls, maps_route, handled_by, returns_dto, reads_config
- invokes_api, uses_component, emits_event
- reads_table, writes_table, executes_query, binds_param, tested_by

## Extraction Targets for Java/Spring
- @Controller, @RestController, @RequestMapping, @Get/Post/Put/DeleteMapping
- @Service, @Repository, @Component
- constructor injection / @Autowired
- JPA entities and repositories
- @Query methods
- JdbcTemplate / NamedParameterJdbcTemplate
- MyBatis mapper interfaces and XML
- Maven/Gradle dependencies

## Extraction Targets for Vue
- .vue SFC files
- props, emits, computed, methods
- component imports and registrations
- Vue Router
- axios/fetch/$http/$axios API calls
- optional store usage if easy to extract

## UI Requirements
- Index tab: project selection, start/reindex, progress, stats, warnings
- Chat tab: conversation, citations to file/line, code preview, open-in-editor, patch preview
- Graph tab: Cytoscape viewer, filters by node/edge type, hop depth, search/highlight, node details panel

## Implementation Rules
- Do not rely on model chat history as memory
- Persist task/session state externally
- Every answer must cite file paths and line ranges
- Use JSON schemas at model boundaries
- Prefer deterministic extraction over LLM inference
- Use the model only for bounded summarization, retrieval planning, and final synthesis
- Unknown is acceptable; hallucination is not

## Phase Plan
### Phase 1
- monorepo skeleton
- SQLite schema
- project scan
- tree-sitter parsers
- ast-grep integration
- repository map MVP
- lexical retrieval MVP
- basic chat API with grounded answers
- Monaco viewer integration
- Cytoscape graph MVP

### Phase 2
- qmd-style vector search + RRF
- query expansion and reranking with vendored local models
- ontology enrichment
- impact analysis
- flow tracing
- editor patch workflow

### Phase 3
- stronger ranking
- snapshot export mode inspired by Repomix
- benchmark/eval harness
- incremental reindex optimization

## First Task
Create `.agent/active-plan.md` and implement Phase 1 skeleton with runnable server/web apps, SQLite schema, indexing pipeline stubs, retrieval stubs, and placeholder UI pages. Prioritize end-to-end wiring over deep feature completeness.

## Definition of Done
- a repository can be indexed once and queried afterward
- chat answers are grounded with file/line evidence
- user can open referenced code in Monaco
- graph viewer shows ontology immediately after indexing
- the product runs on Windows in a closed network using only vendored runtime assets
