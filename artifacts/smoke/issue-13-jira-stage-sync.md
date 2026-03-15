# Issue 13 Jira Stage Sync Proof

Date: 2026-03-15

## Facts

- Ran `scripts/check-stage-reporting`.
- Ran `scripts/check-harness`.
- Both commands passed in this worktree.

## Verification Scope

`scripts/check-stage-reporting` creates an isolated temp repo with mocked `gh`, `codex`, and `curl` binaries and verifies that:

1. a linked issue body carrying `Jira: OPS-9001` resolves into the local task record,
2. the task record appends machine-readable stage summaries for `claim_started`, `executor_started`, and `executor_reconciled_to_pr`,
3. the harness posts concise Jira comments to the linked issue for each of those transitions, and
4. the Jira PR-stage comment includes the PR URL.

`scripts/check-harness` reruns the repository shell checks plus the notification, control-room, executor, and stage-reporting checks together.

## Commands

```bash
scripts/check-stage-reporting
scripts/check-harness
```

## Results

```text
check-stage-reporting passed
check-harness passed
```

## Open Risk

- This proof uses mocked Jira and GitHub HTTP calls, so it validates the harness state model, message formatting, and sync triggers, not a live Jira credential set.
