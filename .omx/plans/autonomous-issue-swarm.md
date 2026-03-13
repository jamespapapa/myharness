# Autonomous Issue Swarm v0.1

## Goal

Move from manager-dispatch mode to issue-driven autonomous execution:

1. Human creates GitHub issues using the harness template.
2. Multiple OpenClaw cron workers wake every 5 minutes.
3. Each worker claims at most one eligible issue.
4. The worker materializes a worktree and launches Codex for implementation.
5. The pipeline advances through review, prepare, and land without human hand-carry unless it blocks.

The operator should scale throughput by adding more cron workers, not by manually dispatching more tasks.

## Status As Of 2026-03-13

Completed in this seed repo:

- `scripts/task-run-once`
- `scripts/task-review`
- `scripts/task-prepare`
- `scripts/task-land`
- one live docs-only issue validated through `issue -> PR -> review -> prepare -> land -> merge`

Still open before broad production rollout:

- project-specific prepare gates
- GitHub required-check enforcement by default
- GitHub issue-form enforcement

## What Changes

### Old default

- Human manager picks an issue.
- Human manager starts the task workspace.
- Human or manager hands the task to Codex.

### New target default

- Human only registers good issues.
- Workers pull from the queue on schedule.
- Issue state and artifacts drive the pipeline.
- Human intervenes only on blocker, policy failure, or escalation.

## Worker Roles

### Role 1: Intake source

- Truth source: GitHub issues only.
- Input quality is enforced by issue template, not by chat memory.
- If an item is not a good issue, it should not enter the autonomous queue.

### Role 2: OpenClaw cron manager

- Wakes on a fixed schedule.
- Runs exactly one `task-run-once` cycle.
- Claims no more than one issue per wake.
- Leaves a structured log and exits.

### Role 3: Codex executor

- Receives one claimed issue in one isolated worktree.
- Implements or blocks.
- Must leave the issue in a terminal harness state before exit.

### Role 4: Review agent

- Reviews the opened PR against the exact head SHA.
- Emits tracked review artifacts.
- Refuses land if the head changed after review.

### Role 5: Prepare agent

- Runs gates against the reviewed head.
- Emits prepare artifacts bound to the exact prepared SHA.
- Refuses land if gates are stale or head drifted.

### Role 6: Land agent

- Merges only when review + prepare artifacts match the current head and required checks are green.
- Posts merge outcome and clears worktree state.

## Queue State Model

Issue labels remain the queue API.

- `harness:in-progress`
- `harness:pr-open`
- `harness:blocked`
- `harness:done`

Add one execution convention:

- only issues that pass the intake template and are eligible under `task-next` enter autonomous execution

Longer term we should add:

- `harness:needs-review`
- `harness:prepared`
- `harness:land-failed`
- `harness:escalate`

## Run-Once Contract

Every cron worker tick should do exactly one of these outcomes:

1. `idle`
   - no eligible issue
   - write one log line
   - exit 0
2. `success`
   - claimed one issue
   - executor left terminal state such as `pr_open` or `done`
   - write one result line
   - exit 0
3. `blocked`
   - claimed issue but task blocked
   - record blocker to GitHub and log
   - exit non-zero
4. `error`
   - failed to claim, materialize, or record a terminal state
   - mark blocked or escalate
   - exit non-zero

Each worker must be disposable. No long-lived in-memory state is trusted.

## Cron Topology

Base topology:

- N identical OpenClaw cron jobs
- same repo
- same issue selection rules
- same `task-run-once` entrypoint
- claim file + GitHub labels prevent double processing

Scaling rule:

- if backlog grows, add more cron jobs
- if queue is empty, workers simply log `idle` and exit

## Review / Prepare / Land Target

The autonomous merge path should look like:

1. Executor opens PR and marks task `pr_open`.
2. Review worker picks one PR-open task and writes `artifacts/reviews/<task-id>/review.md|json`.
3. Prepare worker runs scoped gates and writes `artifacts/prep/<task-id>/prep.md|gates.json`.
4. Land worker verifies:
   - reviewed SHA == prepared SHA == current PR head
   - required checks green
   - merge policy satisfied
5. Land worker merges to `main`, posts result, and marks the task `done`.

## Hard Constraints

- No merge on narrative trust alone.
- No merge if head drifted after review or prepare.
- No task may keep a claim forever; stale claims must expire.
- No worker should hold more than one issue at a time.
- Queue truth must be reconstructable from GitHub state plus tracked artifacts.

## Immediate Implementation Slice

This repo should implement first:

- `scripts/task-run-once`
- log file output under `.harness/logs/`
- cron-swarm operator manual
- environment defaults for autonomous workers

That initial slice is now complete and has been extended to first-pass autoland.

## Next Required Deliverables

- GitHub workflow or bot wiring for required checks
- GitHub issue forms for autonomous intake
- stronger project-specific gate sets
- janitor and escalation policy templates

## ADR

### Decision

Adopt an issue-driven pull swarm instead of manual manager dispatch as the default operating model.

### Drivers

- reduce operator touch per issue
- scale throughput by adding workers, not more human routing
- make issue templates the only intake surface

### Alternatives considered

- keep manual manager dispatch as the primary mode
- long-lived daemon workers instead of disposable cron workers

### Why chosen

Cron pull workers match OpenClaw's scheduled isolated job model and reduce operational coupling.

### Consequences

- intake quality becomes more important
- artifact and gate automation become mandatory for safe merge
- logs and state transitions must be machine-readable

### Follow-ups

- define escalation policy
- add GitHub workflow gates that align with local prepare
