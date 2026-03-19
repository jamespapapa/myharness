# Bootstrap Checklist

## 1. Choose platform baseline
- Node.js 22.13+ or newer
- Windows closed-network target
- vendored native SQLite extension assets ready

## 2. Prepare intake machine
- online staging machine only
- clone/pin upstream references
- save lock manifest and licenses
- prepare vendored npm cache or node_modules
- collect GGUF models

## 3. Create product repo skeleton
- copy `AGENTS.md`
- copy `.agent/PLANS.md`
- copy `docs/architecture/system-architecture.md`
- copy `docs/operations/vendoring-and-intake.md`
- copy `docs/prompts/codex-kickoff.md`

## 4. Give Codex the first task
- read the docs
- create `.agent/active-plan.md`
- implement Phase 1 skeleton end-to-end

## 5. Validate on online machine first
- install dependencies
- run server
- run web app
- create sample project entry
- run indexing on a small Java/Spring + Vue fixture repo
- verify chat/graph/editor pages render

## 6. Freeze offline bundle
- source repo
- lockfile
- node_modules or offline package cache
- models
- sqlite extensions
- notices/licenses
- smoke-test script

## 7. Validate in actual closed network
- start app with no internet
- index sample repo
- verify grounded chat answer
- verify code open in Monaco
- verify graph loads
