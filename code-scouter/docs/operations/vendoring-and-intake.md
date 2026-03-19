# Vendoring and Intake Policy

## Short Answer

Yes: start from upstream references.
No: do not build directly against floating `main` branches.

Use an internet-connected intake machine to collect, review, pin, and vendor selected upstream sources.
Move only pinned artifacts into the closed network.

---

## What to Vendor vs What to Borrow

### Vendor / adopt into runtime path
- qmd concepts and selected source modules
- Node's built-in `node:sqlite` runtime binding plus vendored SQLite extensions when needed
- node-llama-cpp integration
- tree-sitter packages and grammars
- @ast-grep/napi
- Monaco Editor
- Cytoscape.js
- sqlite-vec extension and SQLite helpers

### Borrow ideas only
- Aider repo map design
- Zoekt ranking strategy ideas
- OpenGrok browsing UX ideas
- Joern / code-property-graph edge vocabulary
- Repomix snapshot/export ideas

### Do not put in runtime critical path
- Zoekt runtime
- OpenGrok runtime
- Joern runtime
- QA-Pilot runtime
- RepoContext runtime
- Gitingest runtime

---

## Intake Procedure

### 1. Create a reference intake folder
Example:

third_party/
  intake/
  snapshots/
  notices/
  licenses/
  manifests/

### 2. Clone references on an online staging machine
Clone only what is worth reading or vendoring.

Mandatory:
- qmd

Recommended for reference reading:
- aider docs / repo map reference
- ast-grep reference
- repomix reference

Optional, reference-only:
- zoekt
- opengrok
- joern

### 3. Pin exact versions
For each retained dependency or reference snapshot, record:
- repo URL
- exact commit SHA or release tag
- retrieval date
- reason for inclusion
- runtime vs reference-only classification
- license path

Store this in:
- `third_party/manifests/upstream-lock.json`

### 4. Vendor only needed code
Do not dump large upstream repositories into the product repo unless necessary.
Preferred pattern:
- preserve a clean snapshot under `third_party/snapshots/<name>/`
- copy only the needed source subset into `packages/...` or `third_party/runtime/...`
- keep attribution and licenses intact

### 5. Freeze Node dependencies
- commit lockfile
- optionally keep offline npm tarballs / local registry cache
- preserve native modules and DLLs required for Windows closed-network execution

### 6. Freeze model assets
Store vendored GGUF models under:
- `runtime/models/`

Store metadata in:
- `runtime/models/models.manifest.json`

### 7. Freeze SQLite extensions
Store Windows DLLs or loadable SQLite extension binaries under:
- `runtime/sqlite-ext/`

Document how each is loaded.

---

## Practical Recommendation for qmd

Use qmd as:
- architecture reference
- retrieval algorithm reference
- selected source donor

Do not make the product depend on qmd as an external CLI.
Do not assume shell scripts or external wrappers in the critical path.

Preferred strategy:
1. inspect the current stable qmd release/tag
2. pin an exact commit/tag in the intake manifest
3. vendor the needed retrieval logic patterns
4. rewrite/adapt them into the product’s internal TypeScript modules
5. keep database schema and API surfaces product-specific

This avoids coupling the product to qmd’s repo layout or release behavior.

---

## Recommended Initial Intake Set

### Runtime-focused
- qmd
- tree-sitter core and required grammars
- @ast-grep/napi
- monaco-editor
- cytoscape.js
- sqlite-vec binary/assets
- node-llama-cpp compatible model/runtime assets

### Reference-only
- aider repo map docs snapshot
- repomix docs or source snapshot
- optional zoekt snapshot for ranking ideas
- optional opengrok snapshot for UX ideas
- optional joern docs snapshot for edge vocabulary

---

## Closed-Network Bundle Checklist

Before handoff to the offline environment, ensure all of the following exist:
- source monorepo
- pinned lockfile
- vendored node_modules or offline package cache
- vendored GGUF models
- vendored SQLite extension binaries
- upstream lock manifest
- license and notice files
- build/run instructions tested on Windows
- smoke-test script that starts server and web UI locally

---

## Rules for Codex

When using vendored upstream references:
- do not copy large upstream subsystems blindly
- preserve copyright/license notices
- isolate adapted code clearly
- keep a note of what was copied vs reimplemented
- prefer product-owned interfaces over upstream internal APIs
