# Harness Admin Manual

## Purpose

This harness gives you an operator loop that looks like:

1. Select or create work.
2. Claim the issue in GitHub.
3. Create an isolated worktree.
4. Materialize paired agent session directories for Codex and OpenClaw.
5. Run a worker in that task session.
6. Sync PR-open, blocked, or merged state back to GitHub with one command.

The human manager should spend time deciding scope and priority, not hand-carrying branch names, labels, and comments.

## Current State

- The full four-lane path has been exercised against a live GitHub issue in this repo.
- Validated outcome: `issue -> PR -> review artifact -> prepare artifact -> merge`.
- `task-land` now performs the merge when review and prepare artifacts match the current PR head and base.
- Queue selection is currently oldest eligible issue first, gated by the `Ready` label by default and overrideable with `--label`.
- `task-control-room-once` now advances `land -> prepare -> review -> executor` from one repo-level wake loop.
- The current validation depth is one docs-only issue. For a real codebase, you still need project-specific gates and required-check policy.
- Issue intake quality is still a policy and script convention here, not a GitHub-enforced issue form.

## What Is Included

- Root [AGENTS.md](/Users/jules/Desktop/work/myharness/AGENTS.md): repo-level operating contract.
- [project.yaml](/Users/jules/Desktop/work/myharness/.harness/project.yaml): machine-readable topology, runner, and queue defaults.
- [project.env](/Users/jules/Desktop/work/myharness/.harness/project.env): harness defaults.
- Codex task profile: [.harness/profiles/codex/AGENTS.md](/Users/jules/Desktop/work/myharness/.harness/profiles/codex/AGENTS.md)
- OpenClaw task profile: [.harness/profiles/openclaw-task/AGENTS.md](/Users/jules/Desktop/work/myharness/.harness/profiles/openclaw-task/AGENTS.md)
- OpenClaw manager profile: [.harness/profiles/openclaw-manager/AGENTS.md](/Users/jules/Desktop/work/myharness/.harness/profiles/openclaw-manager/AGENTS.md)
- Autonomous swarm guide: [ops/AUTONOMOUS_SWARM.md](/Users/jules/Desktop/work/myharness/ops/AUTONOMOUS_SWARM.md)
- Runtime scripts in `scripts/`

## Prerequisites

- `git`
- `gh`
- `jq`
- `codex`
- `openclaw`
- `gh auth status` succeeds for the target repo

## Bootstrap

1. Review [project.yaml](/Users/jules/Desktop/work/myharness/.harness/project.yaml) and adjust the control-tower channel key, execution channels, runner paths, queue defaults, and `manager_dir` for the project.
2. Review [project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) and adjust runtime integrations or base branch settings if needed.
3. Run `scripts/openclaw-manager-setup`.
4. Start the manager session from the rendered `manager_dir` path from `project.yaml` (default: `.harness-manager/openclaw`).

## Production Checklist

Before you trust autonomous merge on a real repository:

1. Update [.harness/prepare.commands](/Users/jules/Desktop/work/myharness/.harness/prepare.commands) with the repo's real `lint`, `test`, `build`, and invariant commands.
2. Set `HARNESS_REQUIRE_GREEN_CHECKS="1"` in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) if GitHub checks must be green before merge.
3. Confirm the queue gate and execution slot count you want in [project.yaml](/Users/jules/Desktop/work/myharness/.harness/project.yaml) (current defaults: one control tower, one execution slot, queue label `Ready`).
4. If you want Jira comments, set `HARNESS_JIRA_BASE_URL`, `HARNESS_JIRA_USER_EMAIL`, and `HARNESS_JIRA_API_TOKEN` in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env).
5. Add GitHub issue forms, or require all intake to flow through `scripts/task-intake`.
6. Decide how many executor workers you want, update `topology.execution.slot_count` plus `topology.execution.channels[]` in [project.yaml](/Users/jules/Desktop/work/myharness/.harness/project.yaml), then add the corresponding cron jobs.

## Documentation Coverage Gate

Prepare now runs `scripts/check-doc-coverage` before the normal prepare command list, even when the PR is docs-only.

That gate reads [`.harness/doc-coverage.rules.json`](/Users/jules/Desktop/work/myharness/.harness/doc-coverage.rules.json) and fails when:

- architecture-sensitive paths change without a mapped architecture/admin doc update,
- schema-sensitive paths change without a mapped contract/admin doc update,
- integration-sensitive paths change without a mapped admin/sync doc update,
- operator-policy or verification-gate paths change without a mapped runbook update,
- a new critical doc appears under `ops/` or the major `docs/` categories and `AGENTS.md` does not reference it.

Local `scripts/check-harness` runs the same gate so workers see the failure before review or prepare.

## Manager Session

Launch OpenClaw from the generated manager workspace:

```bash
cd .harness-manager/openclaw
openclaw
```

That workspace contains an `AGENTS.md` tuned for backlog management and script-first orchestration.

## Daily Operator Flow

### 1. Create work when needed

If the work item does not exist yet, create a GitHub issue from the harness:

```bash
scripts/task-intake --title "Add artifact gate for task-review" --body "$(cat <<'EOF'
## Problem

- Review flow is still manual.

## Desired Outcome

- Add a scripted review artifact path.

## Constraints

- Keep the first slice small and shell-based.

## Evidence

- Based on OpenClaw review/prepare/land analysis in ANALYSIS.md.
EOF
)"
```

To create and immediately claim/start it:

```bash
scripts/task-intake --title "..." --body "..." --start
```

## Issue Authoring Contract

If you are creating issues manually in GitHub, keep the body structured so the worker does not have to infer intent:

```md
## Problem

- What is wrong now?

## Desired Outcome

- What should be true when this lands?

## Constraints

- What should not change?
- What risk or scope limits matter?

## Evidence

- Links, logs, screenshots, or concrete context

## Done Conditions

- What proof or behavior is required before merge?
```

If the work should mirror into Jira, add one explicit line anywhere in the body:

```md
Jira: ABC-123
```

You can also use a browse URL instead:

```md
Jira: https://jira.example.test/browse/ABC-123
```

This seed repo does not yet enforce that contract through `.github/ISSUE_TEMPLATE/`, so use `scripts/task-intake` or apply this template manually.

### 2. Pick the next issue

```bash
scripts/task-next          # default queue: oldest eligible issue with label `Ready`
scripts/task-next --label bug
scripts/task-next --label Ready
```

### 3. Claim and create a task workspace

```bash
scripts/task-start --issue 123
scripts/task-start --next --label bug
```

This will:

- create or reuse an isolated worktree,
- create paired session directories:
  - `<worktree>/.harness-session/codex`
  - `<worktree>/.harness-session/openclaw`
- write `TASK.md`, `PR_BODY.md`, and `task.json`,
- label the GitHub issue as in progress,
- comment the claim in GitHub,
- store a local claim record.

### 4. Hand off to a worker

Use the command printed by `task-start`, or manually:

```bash
cd /abs/path/to/worktree/.harness-session/codex
codex
```

For an OpenClaw-driven task worker:

```bash
cd /abs/path/to/worktree/.harness-session/openclaw
openclaw
```

### 5. Sync lifecycle updates

PR opened:

```bash
scripts/task-finish --issue 123 --pr https://github.com/owner/repo/pull/45
```

Blocked:

```bash
scripts/task-finish --issue 123 --blocked "needs maintainer decision on storage schema"
```

Merged:

```bash
scripts/task-finish --issue 123 --merged --pr https://github.com/owner/repo/pull/45
```

## GitHub State Model

The harness mirrors task state with four labels:

- `harness:in-progress`
- `harness:pr-open`
- `harness:blocked`
- `harness:done`

These are created automatically on first use if they do not already exist.

Claims are also tracked locally in `.harness/state/claims.json`. `task-next` prunes stale claims older than `HARNESS_CLAIM_TTL_MINUTES`.

## Stage Summaries

Each task record now keeps a machine-readable stage history in `.harness/tasks/<task-id>/task.json`:

- `last_stage_summary`: most recent stage transition
- `stage_summaries`: append-only history of stage transitions for the task

The stable `stage_id` values are:

- `claim_started`
- `executor_started`
- `executor_reconciled_to_pr`
- `executor_blocked`
- `review_approved`
- `review_rejected`
- `review_blocked`
- `prepare_passed`
- `prepare_failed`
- `prepare_blocked`
- `land_merged`
- `land_failed`
- `land_blocked`

Each summary entry records:

- task and issue reference
- current stage
- what actually happened
- PR link when available
- blocked reason and operator action when relevant

These summaries are intended to be the reusable local reporting surface for the control-room and future integrations.

## Jira Comment Sync

Jira sync is opt-in and configuration-driven. The harness only posts Jira comments when all of these are true:

1. `.harness/project.env` sets `HARNESS_JIRA_BASE_URL`
2. `.harness/project.env` sets `HARNESS_JIRA_USER_EMAIL`
3. `.harness/project.env` sets `HARNESS_JIRA_API_TOKEN`
4. the task or issue body contains an explicit Jira link line such as `Jira: ABC-123`

When enabled, the harness posts concise comments for these major transitions:

- claim started
- executor started
- executor reconciled to PR
- review approved / rejected / blocked
- prepare passed / failed / blocked
- land merged / failed / blocked

Jira comment format:

- task reference
- GitHub issue reference
- current stage label
- what happened in that stage
- PR URL when present
- blocked reason and expected operator action when relevant

The Jira comment body intentionally avoids raw local filesystem paths or full local logs.

## Autonomous Mode

If you want “register GitHub issues and let workers consume them”, use:

```bash
scripts/task-control-room-once
```

That one command performs one repo wake tick:

- advance `prepared` work through land first,
- otherwise advance `reviewed` work through prepare,
- otherwise advance `pr_open` work through review,
- otherwise run executor reconcile/claim logic,
- log one JSONL result line,
- exit.

The executor portion still behaves like this when reached:

- reconcile one stale `in_progress` executor task first when needed,
- pick one eligible issue,
- only claim it if the active executor limit still has capacity,
- create the worktree and Codex session,
- run Codex in full-auto mode,
- require a terminal harness state,
- log one JSONL result line,
- exit.

Expected control-room outcomes:

- `idle`: `Ready` queue empty and no unresolved work in land/prepare/review/executor lanes
- `waiting`: active work still needs another wake, or executor capacity is intentionally full
- `success`: one lane advanced work toward merge or completion
- `blocked`: one lane reconciled a task to `blocked`
- `error`: the worker could not record a valid next state

If `.harness/project.env` sets `HARNESS_CONTROL_ROOM_DISCORD_WEBHOOK_URL`, blocked transitions also post one concise operator-facing Discord line that includes:

- task / issue reference
- failing lane (`executor`, `review`, `prepare`, or `land`)
- short reason
- expected operator action when the lane needs intervention

Review rejections also post to the same channel, but as `rejected` rather than `blocked`, so non-escalation outcomes stay visible without looking like harness failures.

See [ops/AUTONOMOUS_SWARM.md](/Users/jules/Desktop/work/myharness/ops/AUTONOMOUS_SWARM.md) for the cron-swarm model.

Manual lane entrypoints remain available:

```bash
scripts/task-run-once
scripts/task-review-once
scripts/task-prepare-once
scripts/task-land-once
```

Those lanes consume local task states in order:

- `pr_open` -> review
- `reviewed` -> prepare
- `prepared` -> land

For real unattended operation, the normal topology is one repo channel or cron wake loop running `scripts/task-control-room-once`.
If backlog grows, add more identical repo-level wakes only intentionally, and keep `HARNESS_EXECUTOR_ACTIVE_LIMIT="1"` unless you want concurrent active executor tasks.

## Paired AGENTS Model

Do not overwrite the tracked root `AGENTS.md`.

Instead:

- Root `AGENTS.md` stays the repo contract.
- Each runtime gets a deeper session directory with its own `AGENTS.md`.
- Launch the runtime from that session directory so the deeper instructions override the root scope.

This gives you a Codex/OpenClaw pair for the same task without mutating tracked repo files.

## Immediate Use Cases

### “OpenClaw manager, pick the next issue and dispatch it”

From the manager workspace, OpenClaw should run:

```bash
../../scripts/task-start --next
```

Then it should hand the generated Codex session path to a worker.

### “OpenClaw manager, turn this design into an issue and start it”

From the manager workspace:

```bash
../../scripts/task-intake --title "..." --body "..." --start
```

### “Codex, work issue #123”

```bash
scripts/task-start --issue 123
cd /abs/path/to/worktree/.harness-session/codex
codex
```

### “Keep processing the next eligible issue”

Repeat:

```bash
scripts/task-start --next
```

The script skips issues already claimed or already labeled as active/PR-open/done.

## Failure Recovery

- Worktree already exists: rerun `task-start`; it reuses the existing workspace.
- Claim got stuck: use `scripts/task-finish --issue <n> --unclaim`.
- Issue blocked: use `--blocked` so the queue state is visible.
- PR opened manually: run `task-finish --pr <url>` after the fact to sync labels and clear the active claim.

## Non-Goals

- This kernel does not use GitHub Projects as the source of truth.

## Upgrade Path

The next kernel layer should add:

- stronger project-specific gates,
- required-check policy wiring,
- janitor automation templates,
- scope-aware CI wiring,
- janitor workflows.
