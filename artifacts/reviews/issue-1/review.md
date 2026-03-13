Verdict: approved

Short summary

This PR adds a README pointer to the smoke artifact location and records durable GitHub references for the live issue-backed workflow. The change is documentation/artifact-only, and the added file is explicit that it is not an immutable review or prepare artifact.

Findings

None.

Residual risks

- The recorded GitHub URLs and timestamps are external references and were not independently revalidated from this local review session.
- The smoke record is intentionally mutable documentation, so future workflow changes could make it stale without affecting code behavior.
