# .codex/

Project-scoped Codex agent scaffolding for ontlab.

## What is here

- `config.toml` — intended feature and custom-agent registrations
- `agents/*.toml` — per-role instructions for ontlab-specific subagents

## Loading note

In this session, the confirmed local working shape is:

- `~/.codex/config.toml`
- agent blocks under `[agents.<name>]`
- absolute `config_file` paths to agent TOML files

Because project-local auto-loading for `.codex/config.toml` was not fully verified from local evidence alone, treat this directory as the repo source of truth. If your Codex build does not auto-load it, copy the relevant `[features]` and `[agents.*]` blocks into `~/.codex/config.toml`.
