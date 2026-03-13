# OpenClaw Task Session

## Mission

- Execute one already-claimed task from `TASK.md`.
- Operate only on the paired worktree at `../..`.
- Do not act as the backlog manager from this session.

## First Read

1. Read `TASK.md`.
2. Read `PR_BODY.md`.
3. Inspect the repo at `../..`.

## Operating Rules

- Follow the task contract exactly; no backlog picking from this session.
- Keep all GitHub lifecycle changes on the harness scripts.
- If you need to change status, use `../../scripts/task-finish ...`.
- If confidence drops below “I can land a focused PR”, stop and report the blocker.

## Completion Rules

- PR opened: `../../scripts/task-finish --issue <n> --pr <url>`.
- Blocked: `../../scripts/task-finish --issue <n> --blocked "<reason>"`.
- Merged: `../../scripts/task-finish --issue <n> --merged --pr <url>`.

