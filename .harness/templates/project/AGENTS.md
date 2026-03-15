# AGENTS.md

## Purpose
- Product mission:
- Primary users or business goal:
- Why this repository exists:

## Long-Lived Constraints
- List only durable constraints that should stay true across many tasks.
- Examples: compliance boundaries, safety rules, architectural invariants, release branch expectations, and integration constraints.

## Harness Ownership Contract
- Shared harness-core paths in this repo are sync-owned and should change only through the approved harness sync flow.
- Project overlay paths are project-owned and may define repo-specific commands, risky paths, and workflow wiring.
- When architecture, schemas, integrations, operator procedures, or release rules change, update the mapped docs instead of expanding this file.

## Document Map
- Architecture: docs/architecture/overview.md
- Schemas: docs/schemas/index.md
- Runbooks: docs/runbooks/operations.md
- Integrations: docs/integrations/index.md
- Release: docs/release/process.md

## Usage Notes
- Keep this file concise and stable.
- Put detailed architecture, schema, runbook, integration, and release content in the mapped docs above.
- If a category is not relevant yet, keep the entry and map it to `N/A (not yet)` until the doc exists.
