# Issue 10 Smoke Proof

Date: 2026-03-13

## Facts

- Ran `scripts/check-task-run-once`.
- Ran `scripts/check-harness`.
- Both commands passed in this worktree.

## Verification Scope

`scripts/check-task-run-once` creates isolated temp repos with mocked `gh` and `codex` binaries and exercises four executor scenarios:

1. Ready issue claims and reconciles to `pr_open`.
2. Active executor limit blocks a new claim while an older task is still running.
3. Queue-empty status reports `waiting`, not `idle`, when active work still exists.
4. Stale `in_progress` executor work reconciles to `pr_open` and clears its claim.

## Commands

```bash
scripts/check-task-run-once
scripts/check-harness
```

## Results

```text
check-task-run-once passed
check-harness passed
```

## Open Risk

- This proof uses mocked GitHub/Codex binaries, so it validates the harness control-room logic and local git transitions, not live GitHub network behavior.
