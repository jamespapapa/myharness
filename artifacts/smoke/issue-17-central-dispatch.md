# Issue 17 Central Dispatch Proof

Date: 2026-03-17
Verification context: refreshed after fixing assigned-claim lifecycle edge cases on `fix/issue-17` for PR #30.

## Facts

- Verified the issue-17 implementation present on `fix/issue-17` after merging the latest `dev` branch.
- Reproduced and fixed these lifecycle cases:
  1. dispatch-only mode must keep queued `rework` work assigned instead of launching it locally;
  2. stale assigned claims must requeue cleanly instead of blocking forever;
  3. assigned-only workers must not start a second task while the same slot/channel already has an `in_progress` claim;
  4. direct `task-start --launch codex` must flip the claim to `in_progress` before Codex starts;
  5. assigned launches must refresh `claimed_at` / `claimed_epoch` when they transition from `assigned` to `in_progress` so they are not immediately reconciled as stale.

## Verification Scope

`scripts/check-task-run-once` creates isolated temp repos with mocked `gh` and `codex` binaries and verifies that:

1. dispatch-only mode claims one eligible issue, records `assignment.slot` / `assignment.channel`, and leaves the claim in `assigned` state without launching Codex,
2. assigned-only mode stays queue-blind when no task is assigned to the worker slot,
3. assigned-only mode executes preassigned work for the matching slot/channel and reconciles it to `pr_open`,
4. dispatch-only mode keeps queued `rework` work assigned for the execution channel instead of launching it locally,
5. expired assigned claims are requeued instead of blocking forever,
6. `task-start --launch codex` marks the claim `in_progress` before worker startup,
7. assigned launches refresh claim timestamps when they start running, and
8. assigned-only workers wait when the same slot/channel already has active running work.

## Commands

```bash
scripts/check-task-run-once
HARNESS_BASE_BRANCH=dev scripts/check-harness
```

## Results

```text
check-task-run-once passed
check-harness passed
```

## Open Risk

- These checks use mocked GitHub and Codex binaries, so they validate the local dispatch/claim lifecycle and executor lane wiring, not a live multi-runner deployment against real network state.
