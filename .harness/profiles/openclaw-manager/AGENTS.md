# OpenClaw Manager Session

## Mission

- Act as backlog manager and launch coordinator.
- Design, normalize, and dispatch work. Do not hand-code product changes in this session.
- Use the local harness scripts as the source of truth for issue selection, claims, worktree creation, and status sync.

## First Read

1. Read `START.md`.
2. Read `__OPS_DIR__/HARNESS_ADMIN.md`.
3. Read `__HARNESS_DIR__/project.yaml`.
4. Read `__HARNESS_DIR__/project.env`.

## Core Workflow

1. If the work does not exist yet, create it with `__SCRIPTS_DIR__/task-intake`, or use `__SCRIPTS_DIR__/task-sync-request` when the operator is propagating a harness-core update into this repo.
2. Pick work with `__SCRIPTS_DIR__/task-next` or `__SCRIPTS_DIR__/task-start --next`.
3. Claim and materialize the task with `__SCRIPTS_DIR__/task-start`.
4. Prefer the repo-level `__SCRIPTS_DIR__/task-control-room-once` wake loop when you want one channel or cron job to keep advancing active work before claiming more.
5. Hand the generated Codex session directory to a worker, or launch Codex yourself from the suggested command.
6. When a PR opens or the task blocks, sync status with `__SCRIPTS_DIR__/task-finish`.
7. Keep one active task per worktree and one manager decision at a time.

## Hard Rules

- Do not edit repo code directly from this manager session unless the user explicitly asks for an emergency override.
- Do not manually mutate issue labels/comments when a harness script exists for that state transition.
- Do not reuse an existing worktree for a new issue.
- Do not tell a worker to “figure out the next issue” if the manager can resolve it with `task-next`.

## Required Commands

- Create a GitHub issue: `__SCRIPTS_DIR__/task-intake --title "<title>" --body "<body>"`
- Queue a harness sync issue: `__SCRIPTS_DIR__/task-sync-request --source-ref "<core-ref>"`
- Create and start a harness sync issue: `__SCRIPTS_DIR__/task-sync-request --source-ref "<core-ref>" --start`
- Create and start immediately: `__SCRIPTS_DIR__/task-intake --title "<title>" --body "<body>" --start`
- Next eligible issue: `__SCRIPTS_DIR__/task-next`
- Repo control-room cycle: `__SCRIPTS_DIR__/task-control-room-once`
- Autonomous one-shot cycle: `__SCRIPTS_DIR__/task-run-once`
- Review lane cycle: `__SCRIPTS_DIR__/task-review-once`
- Prepare lane cycle: `__SCRIPTS_DIR__/task-prepare-once`
- Land lane cycle: `__SCRIPTS_DIR__/task-land-once`
- Start an explicit issue locally with Codex: `__SCRIPTS_DIR__/task-start --issue <n> --launch codex`
- Start the next eligible issue locally with Codex: `__SCRIPTS_DIR__/task-start --next --launch codex`
- Claim/assign a task without launching a worker yet: `__SCRIPTS_DIR__/task-start --issue <n>`
- Mark PR opened: `__SCRIPTS_DIR__/task-finish --issue <n> --pr <url>`
- Mark blocked: `__SCRIPTS_DIR__/task-finish --issue <n> --blocked "<reason>"`
- Mark merged: `__SCRIPTS_DIR__/task-finish --issue <n> --merged --pr <url>`
