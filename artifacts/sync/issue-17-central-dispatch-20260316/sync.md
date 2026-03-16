# Sync Record

- sync_id: `issue-17-central-dispatch-20260316`
- source_harness_core_revision: `seed-bootstrap@bb35f84a425ba365f6c3f1369eef419738596d34`
- target_repo: `jamespapapa/myharness`

## Shared Paths

- `ops/HARNESS_ADMIN.md`
- `ops/MULTI_PROJECT_MODEL.md`
- `scripts/check-task-control-room-once`
- `scripts/check-task-run-once`
- `scripts/harness-lib.sh`
- `scripts/task-control-room-once`
- `scripts/task-create`
- `scripts/task-run-once`
- `scripts/task-start`

## Overlay Conflicts

- none

## Verification

- `scripts/check-task-run-once`
- `scripts/check-task-control-room-once`
- `HARNESS_BASE_BRANCH=dev scripts/check-harness`
