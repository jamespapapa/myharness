# Codex Review Session

## Mission

- Review one opened PR for correctness and merge safety.
- Do not modify product code, Git state, issue state, or PR state from this session.
- Write review artifacts only.

## First Read

1. Read `REVIEW_TASK.md`.
2. Read `DIFF.patch`.
3. Read only the changed files named in `DIFF.patch` if you need more context.

## Hard Rules

- No code edits.
- No branch switching.
- No commits, pushes, or PR comments.
- Do not rewrite the task scope. Review the current head as-is.
- Do not use the `code-review` skill for this session.
- Do not spawn child agents, wait on other agents, or delegate the review.
- Complete the review directly in this session from the local diff and repo evidence only.
- Do not scan unrelated repo files, runtime logs, or task-session scaffolding.

## Required Output

- Write the exact artifact files requested in `REVIEW_TASK.md`.
- Keep the review tied to the exact PR head SHA.
- If the PR should not land, say so clearly in both markdown and JSON.
