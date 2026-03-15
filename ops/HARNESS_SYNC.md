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

- `.harness/project.env`
- `.harness/prepare.commands`
- queue policy files
- integration config
- `AGENTS.md`
- `docs/**`
- product source code

## Enforcement Direction

The long-term enforcement model should use an explicit manifest, for example:

- `.harness/core-owned-paths.json`
- `.harness/project-owned-paths.json`
- or one combined sync manifest

The manifest should be executable truth, not just prose.

## Sync Request Flow

Desired operator flow:

1. harness-core changes land,
2. operator says: `harness core updated; sync this project`,
3. control-tower creates a sync issue,
4. the harness processes that sync issue like ordinary work,
5. a sync PR lands in the project repo,
6. the project runner updates to the new synced core.

## Sync Issue Requirements

A sync issue should record:

- source harness-core version / commit,
- target project repo,
- list of shared paths expected to change,
- likely overlay conflict points,
- required verification steps,
- doc updates or migration notes when needed.

## Prepare / Check Expectations

A project should eventually fail verification when:

- a core-owned path was edited directly without sync metadata,
- a sync changed contract-sensitive files but docs or operator notes were not updated,
- a repo claims to be synced to a given core version but local shared files do not match.

## Local Hotfix Rule

If a project repo must hotfix a shared harness-core path locally to unblock work:

- record that the change is a temporary divergence,
- open a harness-core follow-up immediately,
- back-port the fix into core,
- remove the divergence through the next sync.

Local divergence should be rare and short-lived.

## Success Criteria

The sync model is healthy when:

- shared harness fixes are made once and propagated intentionally,
- project overlays survive sync cleanly,
- direct edits to shared core paths are detectable,
- sync can be requested through ordinary issue-driven workflow rather than out-of-band manual patching.
