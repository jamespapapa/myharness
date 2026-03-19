# Code Scouter

Offline-first repository analysis for Windows closed-network environments.

Current scope:
- first-time indexing into per-project SQLite databases
- grounded repository chat with file/line citations
- Monaco-based code viewing and local edit preview
- ontology graph browsing in a web control UI

Primary runtime constraints:
- Node.js only in the critical path
- local SQLite database per indexed project
- vendored dependencies and assets only
- no cloud services or external CLIs required at runtime

Getting started:
1. `npm install`
2. `npm run dev:server`
3. `npm run dev:web`
4. open the Vite URL and index a local repository

Planning artifacts:
- active task plan: `.agent/active-plan.md`
- durable milestone plans: `.omx/plans/`
