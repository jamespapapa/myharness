# Planning Notes

This repository uses two plan surfaces:

- `.agent/active-plan.md` for the current execution loop
- `.omx/plans/` for durable milestone plans and plan history

Rules:
- Update `.agent/active-plan.md` before and during any multi-file or architectural task.
- Add a dated plan in `.omx/plans/` whenever the task establishes a new milestone, operator rule, or architecture slice.
- Keep plans concrete: acceptance criteria, implementation steps, risks, and verification.
- When code and plan drift, update the plan in the same change instead of leaving stale intent behind.

