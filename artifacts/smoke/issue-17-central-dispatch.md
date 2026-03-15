# Issue 17 Central Dispatch Proof

Date: 2026-03-16
Head: `c68d68a92d9fc79a87ab499cda730238674daec7`

## Facts

- Verified the issue-17 implementation already present on `fix/issue-17`.
- Ran `scripts/check-task-run-once`.
- Ran `scripts/check-task-control-room-once`.
- Ran `scripts/check-harness`.
- All three commands passed in this worktree at the recorded head.

## Verification Scope

`scripts/check-task-run-once` creates isolated temp repos with mocked `gh` and `codex` binaries and verifies that:

1. dispatch-only mode claims one eligible issue, records `assignment.slot` / `assignment.channel`, and leaves the claim in `assigned` state without launching Codex,
2. assigned-only mode stays queue-blind when no task is assigned to the worker slot,
3. assigned-only mode executes preassigned work for the matching slot/channel and reconciles it to `pr_open`,
4. active executor limit enforcement still blocks duplicate claims, and
5. queue-empty and stale-work reconciliation still behave correctly with the new `assigned` state.

`scripts/check-task-control-room-once` verifies that the repo-level control-room loop still evaluates `land -> prepare -> review -> executor` in order and forwards `--dispatch-only`, `--assign-slot`, and `--assign-channel` into the executor lane.

`scripts/check-harness` reruns the repository shell checks together, including the control-room and executor coverage above.

## Commands

```bash
scripts/check-task-run-once
scripts/check-task-control-room-once
scripts/check-harness
```

## Results

```text
check-task-run-once passed
check-task-control-room-once passed
check-harness passed
```

## Open Risk

- These checks use mocked GitHub and Codex binaries, so they validate the local dispatch contract, assignment persistence, and lane wiring, not a live multi-runner deployment against real network state.
