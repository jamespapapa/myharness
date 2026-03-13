# Live Issue Smoke Test Record

- issue: `jamespapapa/myharness#1`
- issue_url: `https://github.com/jamespapapa/myharness/issues/1`
- pr: `#2`
- pr_url: `https://github.com/jamespapapa/myharness/pull/2`
- branch: `fix/issue-1`
- recorded_at: `2026-03-13`

## What This Records

This artifact records the live GitHub issue workflow used to validate the harness against a real repository queue.

## Evidence

- The issue was created in GitHub and claimed by the harness.
- The harness materialized an isolated worktree for `issue-1`.
- Codex produced the change on branch `fix/issue-1`.
- The harness opened PR `#2` for the issue-backed branch.
- Review, prepare, and land are executed against this PR using artifact-backed lanes.

## Notes

- The first executor attempt exposed a `task-run-once` runtime bug around GitHub token handling.
- That harness bug was fixed before the issue branch was advanced for re-review.
