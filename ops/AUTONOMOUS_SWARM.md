# Autonomous Swarm Manual

## Purpose

This mode is for issue-only intake:

- you register work as GitHub issues,
- disposable workers wake on a schedule,
- each worker takes at most one issue,
- Codex executes in an isolated worktree,
- the worker logs one terminal result and exits.

Use this mode when you want throughput scaling by adding more workers, not by manually dispatching more tasks.

## Validated Scope

As of 2026-03-13, this repo has live-validated:

- one real GitHub issue intake,
- one isolated executor run,
- one review artifact pass,
- one prepare artifact pass,
- one `task-land` merge to `main`.

Validation reference:

- issue: `jamespapapa/myharness#1`
- pr: `https://github.com/jamespapapa/myharness/pull/2`
- result: merged with review / prepare / land artifacts recorded under `artifacts/`

## Current Scope

Implemented now:

- issue selection
- active executor limit with reconcile-before-claim dispatch
- claim + worktree materialization
- Codex executor launch
- one-line result logging
- review lane scripts
- prepare lane scripts
- land lane scripts
- blocked/error recovery when the executor exits without a final harness state

Planned next:

- stronger project-specific gates
- GitHub-required-check wiring
- GitHub issue-form enforcement

## Required Files

- [project.env](/Users/jules/Desktop/work/myharness/.harness/project.env)
- [task-run-once](/Users/jules/Desktop/work/myharness/scripts/task-run-once)
- [HARNESS_ADMIN.md](/Users/jules/Desktop/work/myharness/ops/HARNESS_ADMIN.md)
- [autonomous plan](/Users/jules/Desktop/work/myharness/.omx/plans/autonomous-issue-swarm.md)

## Worker Contract

Each worker tick must do exactly one of:

1. `idle`
2. `waiting`
3. `success`
4. `blocked`
5. `error`

It must leave a JSONL line in `.harness/logs/task-run-once.jsonl` and then stop.
`idle` means the Ready queue is empty and there is no unresolved active executor work.
`waiting` means the Ready queue is empty but active work is still running/reconciling, or the active executor limit is already full.

## Local Cron Example

One worker every 5 minutes:

```bash
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-run-once >> /Users/jules/Desktop/work/myharness/.harness/logs/worker-1.stdout.log 2>&1
```

Three workers:

```bash
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-run-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/worker-1.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/worker-1.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-run-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/worker-2.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/worker-2.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-run-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/worker-3.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/worker-3.stdout.log 2>&1
```

The claim lock and GitHub state sync prevent the same issue from being taken twice.
The safe default is `HARNESS_EXECUTOR_ACTIVE_LIMIT="1"`, so one-shot executor dispatch stays serialized unless the operator raises that limit intentionally.

## Four-Lane Cron Shape

For full automation, run separate one-shot jobs per lane:

```bash
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-run-once >> /Users/jules/Desktop/work/myharness/.harness/logs/executor.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-review-once >> /Users/jules/Desktop/work/myharness/.harness/logs/review.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-prepare-once >> /Users/jules/Desktop/work/myharness/.harness/logs/prepare.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-land-once >> /Users/jules/Desktop/work/myharness/.harness/logs/land.stdout.log 2>&1
```

That gives you:

- `task-run-once`: issue -> PR
- `task-review-once`: PR -> review artifact
- `task-prepare-once`: reviewed PR -> prepare artifact
- `task-land-once`: prepared PR -> merge or wait

Recommended production topology:

- scale `task-run-once` horizontally
- keep one `task-review-once`
- keep one `task-prepare-once`
- keep one `task-land-once`

Increase review/prepare/land workers only if those lanes become the actual bottleneck.

## OpenClaw Cron Shape

OpenClaw's cron model supports isolated scheduled jobs. The harness entrypoint for that model should be one run-once cycle per wake.

Conceptually:

```bash
openclaw cron add \
  --name "harness-worker-1" \
  --every "5m" \
  --session isolated \
  --message "In /Users/jules/Desktop/work/myharness, run ./scripts/task-run-once once, log the result, and exit." \
  --no-deliver
```

If you need more throughput, add more identical jobs with different names.

## Operator Workflow

1. Write a good GitHub issue using the harness intake format.
2. Do not manually dispatch it.
3. Wait for a worker tick to claim it.
4. If stdout or JSONL says `waiting`, inspect whether the Ready queue is empty or an older executor task is still running/reconciling.
5. If the task blocks, inspect the GitHub comment and the JSONL log.
6. If backlog exceeds worker throughput, add more worker cron jobs, then raise `HARNESS_EXECUTOR_ACTIVE_LIMIT` only if you intentionally want more than one active executor task.

## Intake Contract

This repo does not yet enforce GitHub issue forms, so "good issue" currently means:

- one task only,
- concrete problem statement,
- desired outcome,
- constraints,
- evidence or links,
- done conditions.

If you want the strongest path today, use `scripts/task-intake` instead of freehand issue creation.

## Queue Hygiene

- Keep issues small.
- Do not mix multiple unrelated asks in one issue.
- Use labels if you want workers filtered to a subset, then pass the label to `task-run-once --label ...`.
- Treat blocked tasks as operator work, not as invisible retries.

## Current Limitation

The four-lane pipeline has now been exercised against a live end-to-end PR in this repo:

- issue: `jamespapapa/myharness#1`
- pr: `https://github.com/jamespapapa/myharness/pull/2`
- outcome: `executor -> review -> prepare -> land -> merge`

Treat the current state as:

- executor lane: live-validated
- review/prepare/land lanes: live-validated for a docs-only issue

For a real codebase, safe unattended merge still depends on:

- meaningful project gates in `.harness/prepare.commands`
- `HARNESS_REQUIRE_GREEN_CHECKS="1"` where GitHub checks matter
- issue-form or intake enforcement so workers see consistently structured tasks

## Runtime Bounds

One-shot lanes are now bounded by default so cron workers do not hang indefinitely:

- `HARNESS_EXECUTOR_TIMEOUT_SECONDS`
- `HARNESS_EXECUTOR_ACTIVE_LIMIT`
- `HARNESS_REVIEW_TIMEOUT_SECONDS`
- `HARNESS_PREPARE_TIMEOUT_SECONDS`
- `HARNESS_LAND_TIMEOUT_SECONDS`
