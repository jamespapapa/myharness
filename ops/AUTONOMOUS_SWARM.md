# Autonomous Swarm Manual

## Purpose

This mode is for issue-only intake:

- you register work as GitHub issues,
- disposable workers wake on a schedule,
- each worker takes at most one issue,
- Codex executes in an isolated worktree,
- the worker logs one terminal result and exits.

Use this mode when you want throughput scaling by adding more workers, not by manually dispatching more tasks.

Default queue gate in this seed:

- workers only consume issues labeled `Ready` unless you override the label filter explicitly.

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
- repo-level control-room tick for `land -> prepare -> review -> executor`
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
- [task-control-room-once](/Users/jules/Desktop/work/myharness/scripts/task-control-room-once)
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

It must leave a JSONL line in `.harness/logs/task-control-room-once.jsonl` or the lane-specific log and then stop.
`idle` means the Ready queue is empty and there is no unresolved active work in land/prepare/review/executor lanes.
`waiting` means the Ready queue is empty but active work is still running/reconciling, or a higher-priority lane still needs another wake before new claims.

## Local Cron Example

One repo-level worker every 5 minutes:

```bash
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-control-room-once >> /Users/jules/Desktop/work/myharness/.harness/logs/control-room.stdout.log 2>&1
```

Three repo channels using the same control-room tick:

```bash
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-control-room-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/control-room-1.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/control-room-1.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-control-room-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/control-room-2.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/control-room-2.stdout.log 2>&1
*/5 * * * * cd /Users/jules/Desktop/work/myharness && ./scripts/task-control-room-once --log-file /Users/jules/Desktop/work/myharness/.harness/logs/control-room-3.jsonl >> /Users/jules/Desktop/work/myharness/.harness/logs/control-room-3.stdout.log 2>&1
```

The claim lock and GitHub state sync prevent the same issue from being taken twice.
The safe default is `HARNESS_EXECUTOR_ACTIVE_LIMIT="1"`, so one-shot executor dispatch stays serialized unless the operator raises that limit intentionally.

## Control-Room Wake Order

The repo-level control-room tick checks lanes in this order and stops on the first non-idle result:

```bash
land -> prepare -> review -> executor
```

That means one wake loop will:

- merge already-prepared work first,
- then run prepare for reviewed PRs,
- then run review for open PRs,
- then reconcile executor work and only claim new `Ready` issues if the repo is otherwise quiet.

The manual lane scripts remain available if you want to debug or scale a specific stage:

```bash
scripts/task-run-once
scripts/task-review-once
scripts/task-prepare-once
scripts/task-land-once
```

Recommended production topology:

- start with one repo channel running `scripts/task-control-room-once`
- add more identical control-room wakes only if you intentionally want more repo-level concurrency
- keep `HARNESS_EXECUTOR_ACTIVE_LIMIT="1"` unless you explicitly want multiple active executor tasks

## OpenClaw Cron Shape

OpenClaw's cron model supports isolated scheduled jobs. The harness entrypoint for that model should be one run-once cycle per wake.

Conceptually:

```bash
openclaw cron add \
  --name "harness-worker-1" \
  --every "5m" \
  --session isolated \
  --message "In /Users/jules/Desktop/work/myharness, run ./scripts/task-control-room-once once, log the result, and exit." \
  --no-deliver
```

If you need more throughput, add more identical jobs with different names.

## Operator Workflow

1. Write a good GitHub issue using the harness intake format.
2. Do not manually dispatch it.
3. Add the `Ready` label when the issue is actually eligible for autonomous pickup.
4. Wait for a control-room tick to advance the repo.
5. If stdout or JSONL says `waiting`, inspect whether active work is still running/reconciling or a higher-priority lane still needs another wake.
6. If stdout or JSONL says `idle`, the `Ready` queue and all active lanes are empty.
7. If the task blocks, inspect the GitHub comment and the JSONL log.
8. If backlog exceeds worker throughput, add more worker cron jobs, then raise `HARNESS_EXECUTOR_ACTIVE_LIMIT` only if you intentionally want more than one active executor task.

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
- The default autonomous queue is `Ready`; add that label when an issue is actually eligible for automatic pickup.
- Use `task-control-room-once --log-file ...`, `task-run-once --label ...`, or `task-next --label ...` if you want to override the default queue gate for a specific run.
- Treat blocked tasks as operator work, not as invisible retries.

## Current Limitation

The repo-level control-room path now wraps the validated four-lane pipeline that has been exercised against a live end-to-end PR in this repo:

- issue: `jamespapapa/myharness#1`
- pr: `https://github.com/jamespapapa/myharness/pull/2`
- outcome: `executor -> review -> prepare -> land -> merge`

Treat the current state as:

- control-room lane ordering: covered by scripted checks
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
