# Issue 17 Central Dispatch Proof

Date: 2026-03-16
Verification context: refreshed after merging the latest `dev` into `fix/issue-17` for PR #30.

## Facts

- Verified the issue-17 implementation present on `fix/issue-17` after merging the latest `dev` branch.
- Ran `scripts/check-task-run-once`.
- Ran `scripts/check-task-control-room-once`.
- Ran `HARNESS_BASE_BRANCH=dev scripts/check-harness`.
- All three commands passed in this worktree for the refreshed PR state.

## Verification Scope

`scripts/check-task-run-once` creates isolated temp repos with mocked `gh` and `codex` binaries and verifies that:

1. dispatch-only mode claims one eligible issue, records `assignment.slot` / `assignment.channel`, and leaves the claim in `assigned` state without launching Codex,
2. assigned-only mode stays queue-blind when no task is assigned to the worker slot,
3. assigned-only mode executes preassigned work for the matching slot/channel and reconciles it to `pr_open`,
4. dispatch-only mode keeps queued `rework` work assigned for the execution channel instead of launching it locally, and
5. queue-empty and stale-work reconciliation still behave correctly with the new `assigned` state.

`scripts/check-task-control-room-once` verifies that the repo-level control-room loop still evaluates `land -> prepare -> review -> executor` in order and forwards `--dispatch-only`, `--assign-slot`, and `--assign-channel` into the executor lane.

`HARNESS_BASE_BRANCH=dev scripts/check-harness` reruns the repository shell checks together, including the control-room and executor coverage above, against the current integration branch.

## Commands

```bash
scripts/check-task-run-once
scripts/check-task-control-room-once
HARNESS_BASE_BRANCH=dev scripts/check-harness
```

## Results

```text
check-task-run-once passed
check-task-control-room-once passed
check-harness passed
```

## Open Risk

- These checks use mocked GitHub and Codex binaries, so they validate the local dispatch contract, assignment persistence, and lane wiring, not a live multi-runner deployment against real network state.
