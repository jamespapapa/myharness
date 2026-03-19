import { cp, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { createProjectId, resolveProjectDataDir } from "../../packages/shared/src/index.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const benchmarkFixturePath = path.resolve(__dirname, "../fixtures/phase1-benchmark");

export const PHASE1_BENCHMARK_NAME = "Phase 1 Benchmark";

export interface Phase1BenchmarkWorkspace {
  projectId: string;
  projectName: string;
  repoPath: string;
  cleanup: () => Promise<void>;
}

export function getPhase1BenchmarkFixturePath(): string {
  return benchmarkFixturePath;
}

export async function createPhase1BenchmarkWorkspace(prefix = "code-scouter-phase1-benchmark-"): Promise<Phase1BenchmarkWorkspace> {
  const workspaceRoot = await mkdtemp(path.join(os.tmpdir(), prefix));
  const repoPath = path.join(workspaceRoot, "repo");
  await cp(benchmarkFixturePath, repoPath, { recursive: true });

  const projectName = PHASE1_BENCHMARK_NAME;
  const projectId = createProjectId(repoPath, projectName);

  return {
    projectId,
    projectName,
    repoPath,
    cleanup: async () => {
      await rm(resolveProjectDataDir(projectId), { recursive: true, force: true });
      await rm(workspaceRoot, { recursive: true, force: true });
    },
  };
}

