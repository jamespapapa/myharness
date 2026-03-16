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
- GitHub issue comments as the single external stage trace surface
- tracked review / prepare / land artifacts under `artifacts/`
- GitHub label and issue-state synchronization
- active dev-batch and released-batch tracking in `.harness/state/release-batches.json`
- optional Discord control-room updates for blocked and rejected outcomes
- default queue gating so autonomous fetch consumes only issues labeled `Ready`

## Direction: from one harness repo to many project repos

The intended long-term shape is:

- one shared `harness-core`,
- many project repos with thin project overlays,
- one control-tower channel per project,
- one or more execution channels per project,
- clean runner clones for actual autonomous execution,
- sync-only updates for shared harness-core paths.

In other words: projects may contain harness-core files, but those shared paths should not drift through ad-hoc local edits. They should move through an explicit harness sync flow.

What you still need before using this on a real codebase:

1. Replace [.harness/prepare.commands](/Users/jules/Desktop/work/myharness/.harness/prepare.commands) with project-specific `lint`, `test`, `build`, or invariant gates.
2. Turn on required-check enforcement in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) by setting `HARNESS_REQUIRE_GREEN_CHECKS="1"` if you want merge to wait for GitHub checks.
3. Set `HARNESS_CONTROL_ROOM_DISCORD_WEBHOOK_URL` in [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env) if you want blocked executor/review/prepare/land outcomes and review rejections to post concise operator-facing lines to a Discord control-room channel.
4. Add GitHub issue forms or use `scripts/task-intake` consistently, because this seed repo does not yet enforce intake quality through `.github/ISSUE_TEMPLATE/`.
5. If you want multiple repo channels or wider fan-out, add them on top of the control-room tick intentionally; the safe default here is one repo channel plus one serialized wake loop.

Release tracking:

- issue work targets `HARNESS_INTEGRATION_BRANCH` by default (`dev` in this seed), and merged issue PRs are added automatically to the active batch in `.harness/state/release-batches.json`
- each issue merge into `dev` appends one concise unreleased entry to the root `CHANGELOG.md`
- a `dev` -> `main` promotion PR merged through `scripts/task-land` closes that batch, archives the batch changelog under `artifacts/releases/<batch-id>.md`, stamps every shipped issue with release metadata, and resets `CHANGELOG.md` for the next batch
- the operator inspection commands live in [ops/HARNESS_ADMIN.md](/Users/jules/Desktop/work/myharness/ops/HARNESS_ADMIN.md)

Quick start:

```bash
scripts/openclaw-manager-setup
# launch from the manager_dir rendered from .harness/project.yaml
cd .harness-manager/openclaw && openclaw
```

Autonomous control-room entrypoint:

```bash
scripts/task-control-room-once
```

That one repo-level wake is the safe default. It already resumes queued `rework` tasks before claiming new `Ready` work, so you do not need a separate retry/autotender loop for the normal flow.

Manual/debug per-lane entrypoints:

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
- [ops/MULTI_PROJECT_MODEL.md](/Users/jules/Desktop/work/myharness/ops/MULTI_PROJECT_MODEL.md)
- [ops/HARNESS_SYNC.md](/Users/jules/Desktop/work/myharness/ops/HARNESS_SYNC.md)
- [ops/PROJECT_AGENTS_CONTRACT.md](/Users/jules/Desktop/work/myharness/ops/PROJECT_AGENTS_CONTRACT.md)
- [.harness/project.env](/Users/jules/Desktop/work/myharness/.harness/project.env)
