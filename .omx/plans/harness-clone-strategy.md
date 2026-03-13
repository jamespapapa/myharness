# Harness Clone Strategy v0.1

## Requirements Summary

This repository exists to clone OpenClaw's development harness, not the OpenClaw product itself.

We are copying:

- structured intake,
- task and workspace isolation,
- artifact-first review and merge trust,
- scripted prepare and land gates,
- backlog janitor automation,
- testing and release rituals,
- role-separated agent operation.

We are not copying:

- OpenClaw application code,
- OpenClaw's exact label universe,
- UI-first control room work,
- "many monitors" theater without the underlying operating ritual,
- a single omniscient agent workflow.

## Decision Drivers

1. Reduce lead time from task intake to first verifiable artifact.
2. Make parallel agent work safe without relying on human memory.
3. Shift merge trust from eyeballing to reproducible evidence.

## Principles

1. One task, one workspace.
2. One agent, one session.
3. No evidence, no land.
4. Prefer small slices over heroic batches.
5. Encode repeat decisions in scripts, templates, or policy files.
6. Prefer executable guard scripts over prose-only rules.

## Chosen Architecture

We will build this in two layers:

- `harness-core`: shared contracts, schemas, scripts, workflow templates, janitor rules, and playbooks.
- project overlay: thin project-local manifest and wiring for build/check/test/release commands and risky-path rules.

Execution starts in this repo as the seed implementation, but all new kernel pieces should be written so they can move into a shared `harness-core` package or repo later without redesign.

Override precedence:

1. harness-core defaults
2. project overlay manifest
3. task-local run or artifact metadata
4. explicit operator override

Normal project work should not bypass the first two layers silently.

## Why This Direction

### Option A: Repo-local harness only

Pros:

- fastest to start,
- lowest abstraction cost.

Cons:

- duplicates quickly across projects,
- policy drift becomes likely,
- not aligned with the stated multi-project end state.

### Option B: Shared core plus project overlays from the start

Pros:

- matches the long-term goal,
- keeps policy centralized,
- makes second-project onboarding cheaper.

Cons:

- requires clearer contracts up front,
- slightly slower initial bootstrap.

### Decision

Choose Option B, but bootstrap it in one seed repo first.

That gives us a pilot environment without locking ourselves into copy-paste per project.

## Acceptance Criteria

- Root `AGENTS.md` states mission, non-goals, isolation rules, evidence rules, and verification rules.
- The repo has a saved plan for the harness kernel and multi-project direction.
- Phase 1 scope is explicit enough that another agent can start implementing kernel artifacts without re-discovering the strategy.
- The plan defines success metrics, risks, and verification expectations.
- The plan clearly separates what is copied from OpenClaw's workflow and what is intentionally excluded.

## Verification Model To Copy

- Use umbrella commands that fan out into focused gates, rather than one opaque mega-check.
- Detect docs-only and changed-scope diffs so expensive checks run only when relevant.
- Keep local hooks and CI aligned so failures reproduce before review.
- Encode repo-specific invariants as dedicated scripts instead of relying only on generic linting.
- Audit for doc-versus-gate drift so written policy does not outlive actual enforcement.
- Keep the changed-scope bucket mapping in an executable source file and treat that file as policy.
- Bind review and prepare artifacts to exact SHAs so head drift invalidates stale evidence.

## Janitor Model To Copy

- Reason labels are the cleanup API.
- Maintainers apply the label; automation owns the exact response text and lifecycle action.
- Standard reasons should include support redirect, invalid, duplicate, spam, too-much-queue, and stale.
- Manual close/comment paths should be the exception, not the default.

## Phase Plan

### Phase 0: Spec and Policy

Deliverables:

- `AGENTS.md`
- `.harness/project.env`
- `.harness/profiles/codex/AGENTS.md`
- `.harness/profiles/openclaw-task/AGENTS.md`
- `.harness/profiles/openclaw-manager/AGENTS.md`
- `ops/PRINCIPLES.md`
- `ops/TAXONOMY.md`
- `ops/REVIEW_POLICY.md`
- `ops/TESTING.md`
- `ops/RELEASE.md`
- `ops/JANITOR.md`
- `ops/HARNESS_ADMIN.md`
- `ops/AUTONOMOUS_SWARM.md`

Goals:

- freeze the language of the workflow,
- define role contracts,
- define artifact schema expectations,
- define minimum label taxonomy,
- define merge trust policy.

Exit criteria:

- another agent can describe the intended review/prepare/land flow without opening OpenClaw.

### Phase 1: Kernel in One Repo

Deliverables:

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/pull_request_template.md`
- `.github/labeler.yml`
- `.github/workflows/labeler.yml`
- `.github/workflows/stale.yml`
- `.github/workflows/auto-response.yml`
- `scripts/committer`
- `scripts/task-next`
- `scripts/task-intake`
- `scripts/task-create`
- `scripts/task-start`
- `scripts/task-run-once`
- `scripts/task-finish`
- `scripts/openclaw-manager-setup`
- `scripts/check-harness`
- `scripts/task-review-once`
- `scripts/task-review`
- `scripts/task-prepare-once`
- `scripts/task-prepare`
- `scripts/task-land-once`
- `scripts/task-land`
- `scripts/ci-changed-scope.mjs`
- `scripts/check-*`
- pre-commit or equivalent local gate wiring

Goals:

- create structured intake,
- create a manager path that can normalize a new work item into a GitHub issue and optionally start it immediately,
- create a manager loop that can pick, claim, and dispatch the next issue,
- create a cron-friendly one-shot worker that can claim one issue, launch Codex, log a terminal result, and exit,
- create paired OpenClaw and Codex task sessions without overwriting the tracked root `AGENTS.md`,
- create scoped commit safety,
- create artifact-emitting review and prepare paths,
- create a single scripted landing path,
- create minimal queue janitor automation,
- make label-driven janitor actions the default cleanup path,
- bind review and prepare evidence to exact heads from the start,
- establish local and CI parity for the baseline gates.

Exit criteria:

- two or three agents can work in parallel without trampling each other,
- scripted land is safer than ad-hoc git merging,
- small tasks can produce a review or plan artifact within 30 minutes.

### Phase 2: Trust Hardening

Deliverables:

- `artifacts/reviews/<task-id>/review.md`
- `artifacts/reviews/<task-id>/review.json`
- `artifacts/prep/<task-id>/prep.md`
- `artifacts/prep/<task-id>/gates.json`
- `artifacts/land/<task-id>/land.json`

Goals:

- make merge trust artifact-backed,
- record reviewed head, prepared head, and landed head,
- require stronger evidence for risky paths and behavior changes,
- define docs-only skip rules and runtime gate rules,
- define changed-scope lane selection and reusable invariant checks.

Exit criteria:

- merges depend more on artifacts plus CI than on manual diff reading,
- bug-fix claims can be audited from stored evidence.

### Phase 3: Shared Core Extraction

Deliverables:

- `harness-core/` or equivalent package split,
- `.harness/project.yaml` manifest schema,
- repo bootstrap and sync mechanism,
- reusable workflow templates.

Goals:

- separate universal kernel from project-local settings,
- move command differences into project manifests,
- keep project overlays thin.

Exit criteria:

- a second repo can adopt the harness mostly by manifest plus overlay wiring.

### Phase 4: Cross-Project Rollout

Deliverables:

- repo registry,
- shared queue rules,
- janitor automation across repos,
- cross-project metrics.

Goals:

- operate multiple projects with the same kernel,
- standardize triage, evidence, and landing across repos.

Exit criteria:

- second-project onboarding time drops materially,
- queue pressure remains manageable without expanding human review load linearly.

### Phase 5: Observability and Control Room

Deliverables:

- review/prepare/land status board,
- artifact completeness metrics,
- PR size and lead-time metrics,
- stale and support-noise metrics.

Goals:

- improve operator visibility after the ritual is stable.

Exit criteria:

- the dashboard reflects an already-working system instead of substituting for one.

## Initial Role Contracts

- Triage Agent: normalize intake, classify, route.
- Planner Agent: define scope, acceptance criteria, and next artifact.
- Implementer Agent: make the scoped change only.
- Reviewer Agent: produce review artifacts, not broad refactors.
- Preparer Agent: run gates, sync head, emit prepare artifacts.
- Lander Agent: verify invariants, land only when evidence is complete.
- Janitor Agent: stale/support/invalid/duplicate handling.
- Release Agent: run release checklist and smoke validation.
- Human Operator: handles exceptions, tradeoffs, and policy changes.

## Minimal Initial Taxonomy

- `bug`
- `enhancement`
- `docs`
- `infra`
- `agent`
- `ui`
- `size: XS`
- `size: S`
- `size: M`
- `size: L`
- `size: XL`
- `support`
- `invalid`
- `duplicate`
- `stale`

Do not copy OpenClaw's full label set at bootstrap time.

## Risks and Mitigations

- Risk: We imitate OpenClaw's surface rituals without reproducing the underlying gates.
  - Mitigation: prioritize scripts, artifacts, and policy docs before dashboards or orchestration UX.

- Risk: The first version becomes repo-specific and hard to extract into shared core.
  - Mitigation: force project-specific commands and risky paths into a manifest contract early.

- Risk: Agents create noise instead of leverage.
  - Mitigation: keep role boundaries narrow and require fixed outputs per role.

- Risk: Merge trust remains narrative-based.
  - Mitigation: make review, prep, and land artifacts mandatory for the scripted path.

- Risk: Queue volume outruns human throughput.
  - Mitigation: automate janitor flows and keep intake structured.

- Risk: Docs describe a workflow that the executable gates no longer enforce.
  - Mitigation: treat gate code as source of truth and create a standing doc-sync check in Phase 2.

## Verification Strategy

For this planning phase:

- Verify that `AGENTS.md` matches the repository mission and guardrails.
- Verify that this plan is concrete enough to drive Phase 1 implementation.
- Verify that every future kernel script has a named place in the roadmap.

For future runtime work:

- docs-only: docs checks only,
- policy or scripts: script-specific smoke plus shellcheck or equivalent,
- workflow changes: dry-run or fixture-based validation,
- runtime changes: build, check, test, and stored artifacts.

## ADR

- Decision: Build a multi-project harness by seeding a shared-core design in this repo, then extracting reusable kernel pieces behind project manifests.
- Drivers: lead time, safe parallelism, and evidence-backed merge trust.
- Alternatives considered: repo-local harness only; full shared platform before pilot.
- Why chosen: it keeps the first implementation concrete while preserving the multi-project target state.
- Consequences: we must write explicit contracts early and resist repo-specific shortcuts.
- Follow-ups: author policy docs, implement kernel scripts, define artifact schemas, then add manifest-based overlays.
