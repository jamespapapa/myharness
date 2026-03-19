import { createServer } from "node:http";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { answerQuestion } from "../../../packages/chat/src/index.js";
import {
  buildPatchPreview,
  ChatRequestSchema,
  getRepoRoot,
  IndexRequestSchema,
  PatchPreviewRequestSchema,
} from "../../../packages/shared/src/index.js";
import {
  getProjectFileContent,
  getProjectGraph,
  getProjectSummary,
  indexProject,
  listProjects,
  openProjectDb,
} from "../../../packages/indexer/src/index.js";
import { corsHeaders, readJsonBody, sendError, sendJson, serveStaticFile } from "./http.js";

const DEFAULT_PORT = Number(process.env.CODE_SCOUTER_PORT ?? 4312);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distRoot = path.resolve(__dirname, "../../web/dist");

export function createAppServer() {
  return createServer(async (request, response) => {
    const requestUrl = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
    const pathname = requestUrl.pathname;

    if (request.method === "OPTIONS") {
      response.writeHead(204, corsHeaders());
      response.end();
      return;
    }

    try {
      if (request.method === "GET" && pathname === "/api/health") {
        sendJson(response, 200, {
          ok: true,
          repoRoot: getRepoRoot(),
          staticWebAvailable: pathExists(distRoot),
        });
        return;
      }

      if (request.method === "GET" && pathname === "/api/projects") {
        sendJson(response, 200, { projects: listProjects() });
        return;
      }

      if (request.method === "POST" && pathname === "/api/projects/index") {
        const payload = IndexRequestSchema.parse(await readJsonBody(request));
        const summary = await indexProject(payload);
        sendJson(response, 200, { project: summary });
        return;
      }

      const projectMatch = pathname.match(/^\/api\/projects\/([^/]+)$/);
      if (request.method === "GET" && projectMatch) {
        const summary = getProjectSummary(projectMatch[1]!);
        if (!summary) {
          sendError(response, 404, "Project not found.");
          return;
        }
        sendJson(response, 200, { project: summary });
        return;
      }

      const chatMatch = pathname.match(/^\/api\/projects\/([^/]+)\/chat$/);
      if (request.method === "POST" && chatMatch) {
        const projectId = chatMatch[1]!;
        if (!getProjectSummary(projectId)) {
          sendError(response, 404, "Project not found.");
          return;
        }
        const payload = ChatRequestSchema.parse(await readJsonBody(request));
        const db = openProjectDb(projectId);
        try {
          const chatResponse = answerQuestion(db, projectId, payload);
          sendJson(response, 200, chatResponse);
        } finally {
          db.close();
        }
        return;
      }

      const fileMatch = pathname.match(/^\/api\/projects\/([^/]+)\/files\/content$/);
      if (request.method === "GET" && fileMatch) {
        const filePath = requestUrl.searchParams.get("path");
        if (!filePath) {
          sendError(response, 400, "Missing file path.");
          return;
        }
        const fileContent = getProjectFileContent(fileMatch[1]!, filePath);
        if (!fileContent) {
          sendError(response, 404, "File not found in project index.");
          return;
        }
        sendJson(response, 200, fileContent);
        return;
      }

      const patchMatch = pathname.match(/^\/api\/projects\/([^/]+)\/patch-preview$/);
      if (request.method === "POST" && patchMatch) {
        const payload = PatchPreviewRequestSchema.parse(await readJsonBody(request));
        const fileContent = getProjectFileContent(patchMatch[1]!, payload.filePath);
        if (!fileContent) {
          sendError(response, 404, "File not found in project index.");
          return;
        }
        const patch = buildPatchPreview(fileContent.content, payload.content, payload.filePath);
        sendJson(response, 200, { patch, changed: fileContent.content !== payload.content });
        return;
      }

      const graphMatch = pathname.match(/^\/api\/projects\/([^/]+)\/graph$/);
      if (request.method === "GET" && graphMatch) {
        const graph = getProjectGraph(graphMatch[1]!);
        sendJson(response, 200, graph);
        return;
      }

      if (request.method === "GET") {
        const requestPath = pathname === "/" ? "/index.html" : pathname;
        const assetPath = path.join(distRoot, requestPath);
        if (await serveStaticFile(response, assetPath)) {
          return;
        }
        const fallback = path.join(distRoot, "index.html");
        if (await serveStaticFile(response, fallback)) {
          return;
        }
      }

      sendError(response, 404, "Route not found.");
    } catch (error) {
      sendError(response, 500, error instanceof Error ? error.message : "Unexpected server error.");
    }
  });
}

function pathExists(targetPath: string): boolean {
  try {
    return existsSync(targetPath);
  } catch {
    return false;
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = createAppServer();
  server.listen(DEFAULT_PORT, () => {
    console.log(`Code Scouter server listening on http://localhost:${DEFAULT_PORT}`);
  });
}
