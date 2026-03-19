# Mission

Build and maintain an offline-first repository analysis product for Windows closed-network environments.

The product must provide:
1. project indexing
2. chat-based repository analysis
3. Monaco-based code viewing/editing
4. ontology graph viewing

This repository prioritizes:
- deterministic extraction before LLM inference
- SQLite as the only database
- Node.js-first runtime
- vendorable dependencies only in the critical path
- grounded answers with file/line evidence
- safe degradation when evidence is incomplete

---

## Runtime Gate

Any runtime dependency added to the critical path must satisfy all of:
- usable directly from Node.js / TypeScript
- vendorable into the repository or release bundle
- no separate Go / Java / Python / Docker / shell tool installation required on target machines
- no cloud service required
- acceptable for Windows closed-network deployment

If a tool is useful but fails this gate, borrow the idea only and reimplement the required subset.

---

## Approved Runtime Patterns

Approved runtime patterns:
- qmd-inspired hybrid retrieval implemented in-process
- SQLite FTS5 + sqlite-vec
- node-llama-cpp with vendored GGUF models
- tree-sitter parsers
- @ast-grep/napi
- Monaco Editor
- Cytoscape.js

Borrow idea only:
- Aider Repo Map
- Zoekt ranking ideas
- OpenGrok cross-reference UX
- Joern / Code Property Graph edge vocabulary
- Repomix snapshot/export ideas

Rejected for runtime:
- Zoekt runtime dependency
- OpenGrok runtime dependency
- Joern runtime dependency
- QA-Pilot runtime dependency
- RepoContext runtime dependency
- Gitingest runtime dependency

---

## Read First

Before making non-trivial changes, read:
- `docs/architecture/system-architecture.md`
- `docs/operations/vendoring-and-intake.md`
- `.agent/PLANS.md`
- `docs/prompts/codex-kickoff.md`

If a change affects architecture, storage schema, retrieval policy, ontology, or prompt contracts, update the docs in the same change.

---

## Working Style

For simple tasks:
- make the smallest correct change
- keep interfaces typed and explicit
- add tests near the change

For complex tasks:
- create or update `.agent/active-plan.md`
- keep it current while working
- deliver milestone by milestone
- do not wait for extra “next step” prompts unless blocked by missing requirements

Create an ExecPlan if any of the following is true:
- touches more than 3 files
- changes SQLite schema
- changes retrieval orchestration
- changes ontology nodes/edges
- changes summary schema or prompt contracts
- introduces a new subsystem

---

## Hard Constraints

- Assume Windows closed-network deployment by default.
- SQLite is the only database.
- Do not add cloud APIs, SaaS dependencies, remote telemetry, or remote storage to the critical path.
- Do not rely on system-wide tools in the runtime path.
- Do not use shell commands as the main integration surface for search or analysis.
- Do not make the LLM the source of truth for repository structure.
- Do not send full large files or whole modules to the model unless explicitly required.
- Do not present unsupported claims as facts.
- Do not hide uncertainty.

---

## Architecture Rules

### 1. Parsing before prompting
Prefer deterministic extraction using:
- tree-sitter
- ast-grep
- framework-specific detectors
- explicit XML / build-file parsing where needed

Avoid asking the model to discover repository structure from raw large files if deterministic extraction is feasible.

### 2. External memory over chat memory
Persist session and task state externally.
Do not rely on chat history as the only memory.

### 3. Hierarchical prompt artifacts
Prompt-facing context must be layered:
- repo map
- module cards
- file cards
- symbol cards
- evidence spans

### 4. Grounding
Every user-facing answer must include:
- file path
- line range
- symbol name when available
- uncertainty marker if any relation is heuristic

### 5. Safe degradation
Separate:
- observed facts
- inferred possibilities
- unknowns

---

## Retrieval Rules

Default retrieval order:
1. repo map / exact symbol anchors
2. lexical retrieval
3. graph expansion
4. vector retrieval
5. query expansion / reranking only when justified

If lexical retrieval is already strong, skip expensive LLM retrieval stages.

Embeddings are a secondary signal, never the only signal.

---

## Ontology Scope

Keep the ontology practical.
Only add nodes/edges that directly improve:
- code navigation
- impact analysis
- API tracing
- DB tracing
- frontend-backend linkage

Do not add ontology concepts that do not improve one of those workflows.

---

## Primary Target Stack

Optimize first for:
- Java 8-17
- Spring MVC / Spring Boot
- Vue 2-3

Secondary support can come later.

---

## Data and Schema Rules

- Use typed schemas at boundaries.
- Keep SQLite migrations explicit and reversible.
- Store source hashes on derived artifacts.
- Invalidate derived artifacts when upstream source changes.
- Distinguish exact vs heuristic relations.

If schema changes, update:
- persistence models
- API contracts
- prompt schemas
- tests
- architecture docs

---

## Code Quality Rules

- Prefer small modules over god classes.
- Keep indexing, retrieval, ontology, chat orchestration, API, and UI concerns separated.
- Add deterministic tests for parsing, graph building, and retrieval.
- Add golden tests for question-answer behavior.
- Keep retrieval/packing decisions debuggable.

---

## Done Expectations

A completed change should usually include:
- implementation
- tests
- docs updates when needed
- explicit limitations and uncertainty handling
- no unnecessary dependency growth

At the end of a task, summarize:
- what changed
- what was validated
- remaining risks or follow-ups
