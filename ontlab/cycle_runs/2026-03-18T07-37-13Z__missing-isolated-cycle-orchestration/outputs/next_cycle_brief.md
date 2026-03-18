# Next cycle brief

## Proposed focus
- failure bucket: `orchestration gap`
- likely pack / layer: `batch-runner`

## Why
- file-backed state, fan-out selection, fan-in aggregation, and worktree planning now exist
- the next smallest gap is the missing executor that consumes a selected batch and materializes isolated cycle worktrees safely

## Rules
- keep one smallest safe change
- preserve single-promoter fan-in
- do not change core ontology
- do not claim target answer-quality improvement unless target eval metrics move
