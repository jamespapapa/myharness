import { answerQuestion } from "../../../packages/chat/src/index.js";
import { getProjectFileContent, getProjectGraph, indexProject, openProjectDb } from "../../../packages/indexer/src/index.js";
import { createPhase1BenchmarkWorkspace, getPhase1BenchmarkFixturePath } from "../../../test/support/phase1Benchmark.js";

async function run(): Promise<void> {
  const fixture = await createPhase1BenchmarkWorkspace("code-scouter-smoke-");
  try {
    const summary = await indexProject({ repoPath: fixture.repoPath, projectName: fixture.projectName });
    const db = openProjectDb(fixture.projectId);
    const answer = answerQuestion(db, fixture.projectId, { question: "Where is /healthz mapped?" });
    db.close();
    const graph = getProjectGraph(fixture.projectId);
    const file = getProjectFileContent(fixture.projectId, "src/main/java/demo/HealthController.java");

    console.log(
      JSON.stringify(
        {
          fixture: getPhase1BenchmarkFixturePath(),
          summary,
          answer,
          graphCounts: { nodes: graph.nodes.length, edges: graph.edges.length },
          fileCheck: {
            filePath: file?.filePath ?? null,
            language: file?.language ?? null,
            lineCount: file?.lineCount ?? null,
          },
        },
        null,
        2,
      ),
    );
  } finally {
    await fixture.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
