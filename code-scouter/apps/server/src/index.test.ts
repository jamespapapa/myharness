import assert from "node:assert/strict";
import test from "node:test";
import type { AddressInfo } from "node:net";

import type { ChatResponse, FileContentResponse, GraphResponse, ProjectSummary } from "../../../packages/shared/src/index.js";
import { createAppServer } from "./index.js";
import { createPhase1BenchmarkWorkspace } from "../../../test/support/phase1Benchmark.js";

test("server smoke covers health, indexing, chat, graph, and file content APIs", async () => {
  const fixture = await createPhase1BenchmarkWorkspace("code-scouter-server-smoke-");
  const server = createAppServer();

  await new Promise<void>((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve());
  });

  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;

  try {
    const health = (await fetchJson(`${baseUrl}/api/health`)) as {
      ok: boolean;
      repoRoot: string;
      staticWebAvailable: boolean;
    };
    assert.equal(health.ok, true);
    assert.equal(typeof health.staticWebAvailable, "boolean");

    const indexed = (await fetchJson(`${baseUrl}/api/projects/index`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        repoPath: fixture.repoPath,
        projectName: fixture.projectName,
      }),
    })) as { project: ProjectSummary };
    assert.equal(indexed.project.status, "ready");
    assert.equal(indexed.project.projectId, fixture.projectId);

    const projects = (await fetchJson(`${baseUrl}/api/projects`)) as { projects: ProjectSummary[] };
    assert.equal(projects.projects.some((project) => project.projectId === fixture.projectId), true);

    const chat = (await fetchJson(`${baseUrl}/api/projects/${fixture.projectId}/chat`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        question: "Where is /healthz mapped?",
      }),
    })) as ChatResponse;
    assert.equal(chat.citations.length > 0, true);
    assert.equal(chat.citations.some((citation) => citation.filePath === "src/main/java/demo/HealthController.java"), true);
    assert.equal(chat.citations.every((citation) => citation.lineStart > 0 && citation.lineEnd >= citation.lineStart), true);

    const graph = (await fetchJson(
      `${baseUrl}/api/projects/${fixture.projectId}/graph`,
    )) as GraphResponse;
    assert.equal(graph.nodes.some((node) => node.type === "Route"), true);
    assert.equal(graph.nodes.some((node) => node.type === "VueComponent"), true);
    assert.equal(graph.edges.length > 0, true);

    const fileContent = (await fetchJson(
      `${baseUrl}/api/projects/${fixture.projectId}/files/content?path=${encodeURIComponent("src/main/java/demo/HealthController.java")}`,
    )) as FileContentResponse;
    assert.equal(fileContent.language, "java");
    assert.match(fileContent.content, /@GetMapping\("\/healthz"\)/);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    await fixture.cleanup();
  }
});

async function fetchJson(url: string, init?: RequestInit): Promise<unknown> {
  const response = await fetch(url, init);
  const payload = (await response.json()) as unknown;
  assert.equal(response.ok, true);
  return payload;
}
