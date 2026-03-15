# Repository Guidelines

## Mission

- This repository builds our harness, not an end-user product.
- Clone OpenClaw's way of working: structured intake, task isolation, artifact-first review/prepare/land, queue janitors, and scope-aware verification.
- Do not copy OpenClaw product code. Reuse operating ideas, contracts, templates, and workflow patterns only.

## First Read

Before making changes:

1. Read `ANALYSIS.md`.
2. Read the newest plan in `.omx/plans/`.
3. Check `git status --short`.

If a task changes the operating model, update the relevant plan or policy doc first instead of improvising in code.

## Current Phase

This repo is in harness bootstrap mode, but the minimum operator loop must stay runnable.

Current priority order:

1. Codify principles and role contracts.
2. Add kernel scripts for issue claim, worktree creation, paired agent sessions, and status sync.
3. Define artifact schemas and merge gates.
4. Add GitHub workflow templates.
5. Add project manifest and adapter shape for multi-project rollout.
6. Add observability only after the ritual is stable.

## Non-Goals

- Do not build OpenClaw features here.
- Do not optimize for dashboards or UI before the workflow kernel exists.
- Do not add large taxonomy or automation surfaces before the minimum flow works in one repo.

## Operating Rules

- One task, one isolated workspace or worktree.
- One agent, one session.
- Keep tasks small and landable. Default to slices that can produce a first artifact within 30 minutes.
- Prefer narrow role boundaries over a single general-purpose agent.
- Prefer scripts, templates, and policies over repeated human judgment.
- When a rule matters repeatedly, turn it into an executable guard instead of leaving it as prose only.

## Multi-Agent Safety

- Do not switch branches in a shared checkout when parallel work is active.
- Do not use broad staging commands such as `git add .`, `git commit -a`, or `git stash`.
- Do not clean up, overwrite, or revert unrelated work you did not create.
- Commit only the files that belong to the current task.
- If a scoped commit helper exists, use it instead of ad-hoc staging.

## Evidence Rules

- No evidence, no land.
- Every substantial task must leave an artifact in a tracked location.
- Plans live in `.omx/plans/`.
- Review, prepare, land, release, and incident artifacts should live under `artifacts/` once those directories exist.
- Review and prepare artifacts must record the exact head SHA they validated.
- If the head changes after review or prepare, the artifact is stale until re-run.
- Bug-fix claims require:
  - symptom evidence,
  - root cause tied to code or policy,
  - touched path alignment,
  - regression test or explicit manual proof.

## Verification Rules

- Docs-only changes should use the lightest valid verification path.
- Verification should be scope-aware: changed paths decide which gates run.
- The path-to-lane mapping must live in an executable rule file, not only in prose.
- Architecture, schema, integration, and operator-flow changes must update mapped docs; `scripts/check-doc-coverage` enforces this from `.harness/doc-coverage.rules.json`.
- Runtime or policy changes must record exact commands run and results.
- Prefer build/check/test gates over intuition.
- Keep local hooks and CI aligned so the same class of failure is caught before review.
- When verification is skipped, explain why and what risk remains.

## Janitor Rules

- Labels are the janitor API.
- Humans should apply reason labels such as `support`, `invalid`, `duplicate`, or `stale`.
- Automation should own the exact comment, close, lock, and timeout behavior for those labels.
- Avoid ad-hoc manual queue cleanup when the reason fits a standard janitor path.

## Preferred Deliverables

When adding the harness kernel, prioritize these files:

- `ops/PRINCIPLES.md`
- `ops/TAXONOMY.md`
- `ops/REVIEW_POLICY.md`
- `ops/TESTING.md`
- `ops/RELEASE.md`
- `ops/JANITOR.md`
- `ops/HARNESS_ADMIN.md`
- `ops/AUTONOMOUS_SWARM.md`
- `ops/MULTI_PROJECT_MODEL.md`
- `ops/HARNESS_SYNC.md`
- `ops/PROJECT_AGENTS_CONTRACT.md`
- `.harness/project.env`
- `.harness/profiles/**/AGENTS.md`
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
- `scripts/check-*`
- `.harness/project.yaml`

## Runtime Sessions

- Never overwrite the tracked root `AGENTS.md` to feed a specific runtime.
- Runtime-specific instructions must live in deeper session directories so they override the root scope cleanly.
- Provide paired session directories for task workers when both Codex and OpenClaw may run against the same task.
- The manager workspace for OpenClaw should be separate from task workspaces.

## Design Direction

- The long-term target is `harness-core` plus thin per-project overlays.
- Shared policy stays centralized.
- Per-project commands, risky paths, and verification commands stay declarative in the project manifest.
- Precedence must stay explicit: harness-core defaults < project overlay < task/run artifact < explicit operator override.
- Do not hard-code repo-specific behavior into the core unless it is truly universal.
- Multi-project rollout should use one control-tower channel per project plus one or more execution channels, while queue fetch/claim stays centralized.
- Per-project branch strategy should stay declarative: issue work flows through a configurable integration branch, while release promotion stays separate on the release branch.
- Shared harness-core paths inside project repos are sync-owned and should change only through harness sync.
- Project `AGENTS.md` files should stay concise and stable: purpose, long-lived constraints, harness ownership contract, and a map to detailed docs.
- Detailed architecture, schema, ops, and integration knowledge should live in dedicated docs, with AGENTS linking to them instead of duplicating them.
- If a task changes architecture, schema, major integrations, or operator procedures, writing/updating the mapped docs is part of done.

## Multi-Project Reference Docs

- [ops/MULTI_PROJECT_MODEL.md](ops/MULTI_PROJECT_MODEL.md) — control-tower + execution-channel topology, runner model, and dispatch expectations
- [ops/HARNESS_SYNC.md](ops/HARNESS_SYNC.md) — core-owned vs project-owned paths and sync-only update flow
- [ops/PROJECT_AGENTS_CONTRACT.md](ops/PROJECT_AGENTS_CONTRACT.md) — what project AGENTS.md should contain and how doc mapping should work
- [ops/HARNESS_ADMIN.md](ops/HARNESS_ADMIN.md) — operator flow, prepare/check behavior, and runtime administration
- [ops/AUTONOMOUS_SWARM.md](ops/AUTONOMOUS_SWARM.md) — lane ordering and autonomous control-room execution model

## Success Criteria

Use these as default targets for the harness:

- 80%+ of incoming work uses structured intake.
- 90%+ of merges flow through scripted review/prepare/land.
- Median change size trends under 200 changed lines.
- Every active task has its own workspace and session.
- First artifact appears within 30 minutes for small tasks.

## Reporting

- Reports should distinguish facts, inferences, and open risks.
- Prefer file-backed evidence over narrative summaries.
- When changing the workflow, document the new rule in this repo before treating it as standard practice.
- When docs and enforced gates diverge, treat the executable gate as truth and queue a doc-fix artifact immediately.
