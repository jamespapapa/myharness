# Multi-Project Operating Model

This document defines the intended long-term shape of `myharness` when one harness core operates multiple product repositories.

## Goal

Use one shared harness core to run many project repos with the same operating model, while still allowing each project to keep its own:

- product code,
- verification commands,
- long-lived constraints,
- execution channels,
- operator context.

## Core Principle

Separate **shared harness behavior** from **project-specific overlay behavior**.

- Shared harness behavior should evolve in one place and roll out through controlled sync.
- Project-specific overlay behavior should remain editable inside each project repo.

## Topology

Per project, the target topology is:

- **1 control-tower Discord channel**
- **N execution Discord channels**
- **1 canonical project repository**
- **1+ runner clones** for actual execution
- **1 shared harness core source** that syncs into project repos

```text
[harness-core]
   └─ shared scripts / profiles / policies / checks

[project repo]
   ├─ product code
   ├─ project overlay config
   ├─ AGENTS.md
   └─ docs/*

[Discord]
   ├─ #project-control-tower
   ├─ #project-issue-dev-1
   ├─ #project-issue-dev-2
   └─ #project-issue-dev-N

[runner clone(s)]
   ├─ .harness/tasks
   ├─ .harness/logs
   ├─ .harness/state
   └─ worktrees/*
```

The executable topology contract for that layout lives in `.harness/project.yaml`.
This repo stores the file as the JSON subset of YAML so the current shell tooling can read it with `jq` without adding a `yq` dependency.

## Project Topology Manifest

`.harness/project.yaml` is the machine-readable overlay that maps the prose model onto concrete project wiring.

It must define:

- `project.slug`: the canonical owner/repo slug
- `topology.control_tower`: the control-plane channel identity
- `topology.execution.slot_count`: how many execution slots the project can run concurrently
- `topology.execution.channels[]`: the execution-channel identities for each slot
- `topology.runners`: whether the project is single-runner or multi-runner, plus runner/worktree/manager paths
- `topology.queue_policy`: the default queue-claim behavior for the project

Current harness scripts consume that manifest for:

- default queue label selection,
- executor slot count,
- worktree root selection,
- manager workspace location,
- control-tower channel metadata exposed to session tooling.

That keeps the single-project seed flow runnable now while creating one declarative surface for future non-Discord transports.

## Channel Roles

### Control-Tower Channel

Purpose:

- preserve project-level context,
- talk with the operator,
- generate or refine issues,
- decide policy changes,
- trigger harness-core sync,
- handle blocked/escalated work.

This is the **human-facing control plane**.

### Execution Channels

Purpose:

- receive assigned task work,
- run executor / review / prepare / land flows,
- emit concise operational status.

Execution channels should **not independently fetch from the global queue**.
They should only execute work assigned by the control tower or central dispatcher.

## Dispatch Model

Queue selection must stay centralized.

Recommended rule:

- only the control-tower dispatcher fetches eligible work,
- only the control-tower dispatcher claims work,
- execution channels only receive already-claimed tasks.

This avoids duplicate issue selection and keeps prioritization deterministic.

### Recommended Dispatch Loop

1. inspect current active work,
2. advance existing work first,
3. if capacity remains, fetch one eligible issue,
4. claim it,
5. assign it to an execution slot/channel,
6. monitor until next state transition.

## Runner Model

Do not run cron against a developer's working checkout.

Use a clean runner clone per project for autonomous operation.

The runner clone owns:

- task records,
- worktree creation,
- local claims,
- worker logs,
- cron-facing execution.

The canonical repo can remain available for manual development, review, and inspection.

## Branching Model

The kernel now supports a split branch model:

- a configurable integration branch for issue worktree creation, freshness checks, and issue PR targets,
- a separate configurable release branch for later promotion and release metadata,
- `HARNESS_BASE_BRANCH` as a compatibility alias that follows the integration branch by default.

In this seed repo, that means:

- `main` as release branch,
- `dev` as integration branch,
- issue branches cut from `dev`,
- PRs targeted to `dev`,
- later promotion from `dev` to `main` with release metadata.

## Sync Model

Project repositories should contain harness core files, but those files must be treated as **sync-owned**, not directly edited.

See [ops/HARNESS_SYNC.md](./HARNESS_SYNC.md) for the enforcement model.

## Project Overlay Model

Each project repo may customize only overlay surfaces such as:

- `.harness/project.yaml`
- `.harness/project.env`
- `.harness/prepare.commands`
- queue policy / label policy
- integration settings
- AGENTS.md and mapped docs
- product source code

## Documentation Contract

Every project repo should document long-lived invariants and critical references.

- `AGENTS.md` should contain the big picture, constraints, and document map.
- detailed architecture, schema, ops, and integration references should live in dedicated docs.
- AGENTS should link to those docs instead of duplicating them.

See [ops/PROJECT_AGENTS_CONTRACT.md](./PROJECT_AGENTS_CONTRACT.md).

## What Counts as Success

This model is working when:

- one control-tower channel can coordinate many execution channels safely,
- projects can adopt harness-core updates via sync instead of ad-hoc copy/paste,
- project-specific constraints stay local,
- every major stage can be explained concretely,
- the same operating rules work across multiple repos without hand-tuned behavior hidden in core scripts.
