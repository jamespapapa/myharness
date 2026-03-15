# Project AGENTS Contract

This document defines what a project repository's `AGENTS.md` should contain when the project runs on top of harness-core.

Reusable support in this repo:

- Template: `.harness/templates/project/AGENTS.md`
- Validator: `scripts/check-project-agents-contract path/to/AGENTS.md`

## Purpose

`AGENTS.md` should give workers and operators the **stable map** of the project, not act as a dumping ground for every detail.

It should answer:

- what this project is for,
- what cannot be broken,
- where the important reference docs live,
- which parts are harness-core owned versus project-owned.

## What AGENTS.md Should Contain

### 1. Project Purpose

A short explanation of:

- product mission,
- major user or business goal,
- why the repo exists.

### 2. Long-Lived Constraints

Only constraints that are expected to remain stable for a while, such as:

- compliance boundaries,
- non-negotiable safety rules,
- major architectural invariants,
- release branch expectations,
- integration constraints.

### 3. Harness Ownership Contract

The project's AGENTS should explicitly say that:

- harness-core-owned files are sync-owned,
- project overlays remain locally owned,
- workers must not directly mutate shared harness-core paths except through approved sync flow.

### 4. Document Map

AGENTS should link to the documents that hold important detail, for example:

- architecture overview,
- domain model,
- API schema,
- DB schema,
- operations runbook,
- external integration references,
- release process,
- incident / recovery notes.

The map should stay category-based instead of path-rigid:

- use whatever repo-local paths fit the project,
- keep one or more entries for architecture, schemas, runbooks, integrations, and release guidance,
- if a category does not exist yet, map it to `N/A (not yet)` instead of dropping it from the file.

## What AGENTS.md Should Not Contain

Avoid putting these directly in AGENTS unless there is no better document yet:

- large architecture descriptions,
- full schema explanations,
- long operational procedures,
- repeated copies of detailed docs,
- rapidly changing implementation notes.

AGENTS is an **index + invariant contract**, not the whole knowledge base.

## Required Supporting Docs

For serious projects, the repo should eventually maintain at least these categories when relevant:

- `docs/architecture/*`
- `docs/schemas/*`
- `docs/runbooks/*`
- `docs/integrations/*`
- `docs/release/*`

Exact paths may vary, but the categories should be represented.

Recommended homes for detailed docs:

- architecture details: `docs/architecture/*`
- schemas and contracts: `docs/schemas/*`
- operations and operator procedures: `docs/runbooks/*`
- external systems and dependencies: `docs/integrations/*`
- release process and rollout notes: `docs/release/*`

## Documentation Gate Direction

When a task changes any of the following, documentation should be part of done:

- architecture shape,
- schemas or contracts,
- major integrations,
- operator procedures,
- release rules,
- sync / ownership rules.

And when a new important document appears, AGENTS should be updated to map to it.

In this repo, that expectation is enforced by [`scripts/check-doc-coverage`](../scripts/check-doc-coverage) using the explicit path rules in [`.harness/doc-coverage.rules.json`](../.harness/doc-coverage.rules.json).

The rule stays scope-aware on purpose:

- architecture-sensitive paths require updates in mapped architecture docs,
- schema-sensitive paths require updates in mapped contract docs,
- integration-sensitive paths require updates in mapped integration or admin docs,
- operator-policy changes require updates in mapped runbooks or admin docs.

If a new critical doc appears under `ops/` or the major `docs/` categories, `AGENTS.md` must reference that path before the gate passes.

Projects should treat this as a maintenance rule:

- keep `AGENTS.md` short,
- move detail into the mapped docs,
- run `scripts/check-project-agents-contract` in local checks or CI to keep the contract live.

## Minimal Example Shape

```markdown
# AGENTS.md

## Purpose
...

## Long-Lived Constraints
...

## Harness Ownership Contract
- shared harness-core paths are sync-owned
- project overlay paths are locally owned

## Document Map
- Architecture overview: docs/architecture/overview.md
- API schema: docs/schemas/api.md
- Ops runbook: docs/runbooks/ops.md
- External integrations: docs/integrations/index.md
- Release process: docs/release/process.md
```

The validator checks:

- required `Purpose`, `Long-Lived Constraints`, `Harness Ownership Contract`, and `Document Map` sections,
- ownership language for sync-owned and project-owned paths,
- document-map coverage for architecture, schema, runbook, integration, and release categories.

## Success Criteria

This contract is working when:

- workers can orient quickly from AGENTS,
- important detail lives in dedicated docs,
- AGENTS stays concise enough to remain readable,
- the repo can enforce documentation updates as part of task completion.
