# Codex Task Session

## Mission

- Execute exactly one claimed task from `TASK.md` in this directory.
- Treat the sibling git worktree at `../..` as the only code edit scope.
- Do not triage backlog, pick a different issue, or change task ownership from here.

## First Read

1. Read `TASK.md`.
2. Read `PR_BODY.md`.
3. Inspect the repo at `../..`.

## Working Rules

- Keep scope tight to the issue or task contract in `TASK.md`.
- Do not touch `.harness-session/`, `.harness-manager/`, or unrelated runtime files unless the task explicitly requires it.
- Prefer minimal edits and explicit verification over exploratory churn.
- If the task is underspecified or blocked, stop and record the blocker instead of guessing.
- Use the local harness scripts instead of ad-hoc GitHub state changes.

## Required End States

- If you open a PR, run `../../scripts/task-finish --issue <n> --pr <url>`.
- If the task is blocked, run `../../scripts/task-finish --issue <n> --blocked "<reason>"`.
- If the PR is merged, run `../../scripts/task-finish --issue <n> --merged --pr <url>`.
- If the task is local-only and has no issue number, update the local task notes and stop cleanly.

## Commit and PR Rules

- Use one branch per task.
- Keep commits scoped to the task branch only.
- Reuse `PR_BODY.md` as the starting point for the PR description.
- Ensure the PR body links the issue with `Fixes owner/repo#N` when the task is issue-backed.

