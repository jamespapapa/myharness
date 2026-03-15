# myharness

OpenClaw-style operating harness seed.

Current status:

- Live-validated on 2026-03-13 against `jamespapapa/myharness#1` and PR `#2`
- End-to-end path exercised: `issue -> claim -> worktree -> Codex -> PR -> review -> prepare -> land -> merge`
- Review, prepare, and land now run as bounded one-shot lanes suitable for cron workers
- The repo-level control-room tick now advances `land -> prepare -> review -> executor` from one wake loop
- Executor one-shot dispatch stays serialized by default and reconciles stale `in_progress` work before claiming more
- The validation run's queue record lives under `artifacts/smoke/`

What this repo gives you:

- OpenClaw manager workspace generation
- isolated task worktrees with paired OpenClaw and Codex sessions
- one repo-level control-room wake path for channel/cron usage
- one-shot executor, review, prepare, and land workers
- stage-by-stage summaries stored on each local task record
- tracked review / prepare / land artifacts under `artifacts/`
- GitHub label and issue-state synchronization
- optional Jira issue comment sync for linked tasks
- optional Discord control-room updates for blocked and rejected outcomes
- default queue gating so autonomous fetch consumes only issues labeled `Ready`

What you still need before using this on a real codebase:

1. Replace [.harness/prepare.commands](/Users/jules/Desktop/work/myharness/.harness/prepare.commands) with project-specific `lint`, `test`, `build`, or invariant gates.
2. Turn on required-check enforcement in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) by setting `HARNESS_REQUIRE_GREEN_CHECKS="1"` if you want merge to wait for GitHub checks.
3. Set `HARNESS_CONTROL_ROOM_DISCORD_WEBHOOK_URL` in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) if you want blocked executor/review/prepare/land outcomes and review rejections to post concise operator-facing lines to a Discord control-room channel.
4. Set `HARNESS_JIRA_BASE_URL`, `HARNESS_JIRA_USER_EMAIL`, and `HARNESS_JIRA_API_TOKEN` in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env), then include `Jira: ABC-123` or a Jira browse URL in the task body if you want linked tasks to sync concise stage comments into Jira.
5. Add GitHub issue forms or use `scripts/task-intake` consistently, because this seed repo does not yet enforce intake quality through `.github/ISSUE_TEMPLATE/`.
6. If you want multiple repo channels or wider fan-out, add them on top of the control-room tick intentionally; the safe default here is one repo channel plus one serialized wake loop.

Quick start:

```bash
scripts/openclaw-manager-setup
cd .harness-manager/openclaw && openclaw
```

Autonomous control-room entrypoint:

```bash
scripts/task-control-room-once
```

Manual per-lane entrypoints:

```bash
scripts/task-run-once
scripts/task-review-once
scripts/task-prepare-once
scripts/task-land-once
```

Primary docs:

- [AGENTS.md](/Users/jules/Desktop/work/myharness/AGENTS.md)
- [ops/HARNESS_ADMIN.md](/Users/jules/Desktop/work/myharness/ops/HARNESS_ADMIN.md)
- [ops/AUTONOMOUS_SWARM.md](/Users/jules/Desktop/work/myharness/ops/AUTONOMOUS_SWARM.md)
- [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env)
