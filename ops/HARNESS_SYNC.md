# Harness Sync Model

This document defines how shared harness-core updates propagate into project repositories.

## Goal

Allow `myharness` to evolve centrally without letting each project drift into its own incompatible fork.

## Rule

Project repositories may **contain** harness-core files, but they must not treat them as locally owned.

Shared harness-core changes should arrive only through a **harness sync flow**.

## Ownership Classes

### Core-Owned Paths

These paths are controlled by harness-core and should be updated only through sync:

- shared `scripts/`
- shared `.harness/profiles/`
- shared check scripts
- shared policy docs under `ops/`
- any manifest explicitly marked sync-owned

### Project-Owned Paths

These paths belong to the project overlay and may be edited locally:

- `.harness/project.yaml`
- `.harness/project.env`
- `.harness/prepare.commands`
- queue policy files
- integration config
- `AGENTS.md`
- `docs/**`
- product source code

## Executable Ownership Manifest

This repo now treats `.harness/path-ownership.json` as the executable ownership map.

It records:

- sync-owned `core_owned_paths`,
- explicitly local `project_owned_paths`,
- sync metadata paths that authorize shared-core changes.

Anything not listed under `core_owned_paths` remains project-local by default.

Current project-local exceptions include:

- `.harness/project.env`
- `.harness/prepare.commands`
- `.harness/project.yaml`
- `AGENTS.md`
- `docs/**`

The manifest should be executable truth, not just prose. The project topology overlay already follows that rule through `.harness/project.yaml`.

## Sync Request Flow

Desired operator flow:

1. harness-core changes land,
2. operator says: `harness core updated; sync this project`,
3. `scripts/task-sync-request --source-ref "<core-ref>"` creates a structured sync issue,
4. the harness processes that sync issue like ordinary work,
5. a sync PR lands in the project repo,
6. the project runner updates to the new synced core.

This repo now stores the default sync request metadata in `.harness/sync-request.defaults.json`.
`scripts/task-sync-request` reads that tracked file to populate:

- expected shared-path updates,
- likely overlay conflict points,
- default verification requirements.

Explicit operator flags override those defaults for a specific request:

- `--shared-path <path>`
- `--overlay-conflict <path>`
- `--verify <requirement>`
- `--migration-note <note>`

If the request should enter the normal queue immediately, the command adds the repo's default queue label automatically.
If the operator wants to claim it right away, use `--start` and the harness will create the issue and hand it to the normal `task-start` path.

Example:

```bash
scripts/task-sync-request --source-ref harness-core@abc1234
scripts/task-sync-request --source-ref harness-core@abc1234 --start
```

## Sync Issue Requirements

A sync issue should record:

- source harness-core version / commit,
- target project repo,
- list of shared paths expected to change,
- likely overlay conflict points,
- required verification steps,
- doc updates or migration notes when needed.

`scripts/task-sync-request` creates that shape as an ordinary issue body so the resulting work item can move through the same claim, review, prepare, and land flow as any other task.

Until there is a dedicated sync command, the branch must carry explicit sync metadata at:

- `artifacts/sync/<sync-id>/sync.json`
- optional human note: `artifacts/sync/<sync-id>/sync.md`

The JSON metadata must include:

- `sync_id`
- `source_harness_core_revision`
- `target_repo`
- `shared_paths`
- `overlay_conflicts`
- `verification`

## Prepare / Check Expectations

A project should eventually fail verification when:

- a core-owned path was edited directly without sync metadata,
- a sync changed contract-sensitive files but docs or operator notes were not updated,
- a repo claims to be synced to a given core version but local shared files do not match.

The local enforcement path in this repo is now:

1. `scripts/check-sync-owned-paths` computes branch changes against the configured base branch,
2. it blocks edits to `core_owned_paths` unless valid `artifacts/sync/<sync-id>/sync.json` metadata is present,
3. `scripts/check-harness` runs that gate, and
4. `task-prepare` inherits it through `.harness/prepare.commands`.

## Local Hotfix Rule

If a project repo must hotfix a shared harness-core path locally to unblock work:

- record that the change is a temporary divergence,
- open a harness-core follow-up immediately,
- back-port the fix into core,
- remove the divergence through the next sync.

Local divergence should be rare and short-lived.

If a temporary local hotfix touches a sync-owned path, the same branch must still include sync metadata so the divergence is visible and auditable.

## Success Criteria

The sync model is healthy when:

- shared harness fixes are made once and propagated intentionally,
- project overlays survive sync cleanly,
- direct edits to shared core paths are detectable,
- sync can be requested through ordinary issue-driven workflow rather than out-of-band manual patching.
