# Sync Record

- sync_id: `github-only-stage-comments-20260316`
- source_harness_core_revision: `seed-bootstrap@5c97e27a60d5625a07baaffff901f903fcad2e12`
- target_repo: `jamespapapa/myharness`

## Shared Paths

- `.harness/profiles/codex/AGENTS.md`
- `ops/HARNESS_ADMIN.md`
- `scripts/check-release-tracking`
- `scripts/check-review-outcomes`
- `scripts/check-stage-reporting`
- `scripts/check-task-create`
- `scripts/check-task-run-once`
- `scripts/harness-lib.sh`
- `scripts/task-create`
- `scripts/task-finish`
- `scripts/task-land`
- `scripts/task-prepare`
- `scripts/task-review`
- `scripts/task-run-once`
- `scripts/task-start`

## Overlay Conflicts

- none

## Verification

- `bash -n scripts/harness-lib.sh scripts/task-create scripts/task-start scripts/task-finish scripts/task-review scripts/task-prepare scripts/task-land scripts/task-run-once scripts/check-stage-reporting scripts/check-review-outcomes scripts/check-task-run-once`
- `scripts/check-stage-reporting`
- `scripts/check-review-outcomes`
- `scripts/check-task-run-once`
- `HARNESS_BASE_BRANCH=dev scripts/check-harness`
