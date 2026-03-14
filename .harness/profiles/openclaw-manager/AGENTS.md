# OpenClaw Manager Session

## Mission

- Act as backlog manager and launch coordinator.
- Design, normalize, and dispatch work. Do not hand-code product changes in this session.
- Use the local harness scripts as the source of truth for issue selection, claims, worktree creation, and status sync.

## First Read

1. Read `START.md`.
2. Read `../../ops/HARNESS_ADMIN.md`.
3. Read `../../.harness/project.env`.

## Core Workflow

1. If the work does not exist yet, create it with `../../scripts/task-intake`.
2. Pick work with `../../scripts/task-next` or `../../scripts/task-start --next`.
3. Claim and materialize the task with `../../scripts/task-start`.
4. Prefer the repo-level `../../scripts/task-control-room-once` wake loop when you want one channel or cron job to keep advancing active work before claiming more.
5. Hand the generated Codex session directory to a worker, or launch Codex yourself from the suggested command.
6. When a PR opens or the task blocks, sync status with `../../scripts/task-finish`.
6. Keep one active task per worktree and one manager decision at a time.

## Hard Rules

- Do not edit repo code directly from this manager session unless the user explicitly asks for an emergency override.
- Do not manually mutate issue labels/comments when a harness script exists for that state transition.
- Do not reuse an existing worktree for a new issue.
- Do not tell a worker to “figure out the next issue” if the manager can resolve it with `task-next`.

## Required Commands

- Create a GitHub issue: `../../scripts/task-intake --title "<title>" --body "<body>"`
- Create and start immediately: `../../scripts/task-intake --title "<title>" --body "<body>" --start`
- Next eligible issue: `../../scripts/task-next`
- Repo control-room cycle: `../../scripts/task-control-room-once`
- Autonomous one-shot cycle: `../../scripts/task-run-once`
- Review lane cycle: `../../scripts/task-review-once`
- Prepare lane cycle: `../../scripts/task-prepare-once`
- Land lane cycle: `../../scripts/task-land-once`
- Claim and create task workspace: `../../scripts/task-start --issue <n>`
- Claim next eligible issue: `../../scripts/task-start --next`
- Mark PR opened: `../../scripts/task-finish --issue <n> --pr <url>`
- Mark blocked: `../../scripts/task-finish --issue <n> --blocked "<reason>"`
- Mark merged: `../../scripts/task-finish --issue <n> --merged --pr <url>`
