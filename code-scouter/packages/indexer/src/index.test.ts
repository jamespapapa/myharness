import test from "node:test";
import assert from "node:assert/strict";

import { answerQuestion } from "../../chat/src/index.js";
import { getProjectFileContent, getProjectGraph, indexProject, openProjectDb } from "./index.js";
import { createPhase1BenchmarkWorkspace } from "../../../test/support/phase1Benchmark.js";

test("indexProject builds searchable grounded artifacts", async () => {
  const fixture = await createPhase1BenchmarkWorkspace();
  try {
    const summary = await indexProject({ repoPath: fixture.repoPath, projectName: fixture.projectName });
    assert.equal(summary.status, "ready");
    assert.equal(summary.stats.files >= 2, true);
    assert.equal(summary.stats.routes >= 1, true);
    assert.equal(summary.stats.components >= 1, true);

    const db = openProjectDb(fixture.projectId);
    const chat = answerQuestion(db, fixture.projectId, { question: "Where is /healthz mapped?" });
    db.close();

    assert.equal(chat.citations.length > 0, true);
    assert.match(chat.answer, /healthz/i);
    assert.equal(chat.citations.some((citation) => citation.filePath === "src/main/java/demo/HealthController.java"), true);

    const file = getProjectFileContent(fixture.projectId, "src/main/java/demo/HealthController.java");
    assert.equal(file?.language, "java");
    assert.match(file?.content ?? "", /@GetMapping\("\/healthz"\)/);

    const graph = getProjectGraph(fixture.projectId);
    assert.equal(graph.nodes.some((node) => node.type === "Route"), true);
    assert.equal(graph.nodes.some((node) => node.type === "VueComponent"), true);
  } finally {
    await fixture.cleanup();
  }
});
