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
- tracked review / prepare / land artifacts under `artifacts/`
- GitHub label and issue-state synchronization
- default queue gating so autonomous fetch consumes only issues labeled `Ready`

What you still need before using this on a real codebase:

1. Replace [.harness/prepare.commands](/Users/jules/Desktop/work/myharness/.harness/prepare.commands) with project-specific `lint`, `test`, `build`, or invariant gates.
2. Turn on required-check enforcement in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) by setting `HARNESS_REQUIRE_GREEN_CHECKS="1"` if you want merge to wait for GitHub checks.
3. Add GitHub issue forms or use `scripts/task-intake` consistently, because this seed repo does not yet enforce intake quality through `.github/ISSUE_TEMPLATE/`.
4. If you want multiple repo channels or wider fan-out, add them on top of the control-room tick intentionally; the safe default here is one repo channel plus one serialized wake loop.

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
