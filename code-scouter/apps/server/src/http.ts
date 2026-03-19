import { createReadStream, existsSync } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";
import type { IncomingMessage, ServerResponse } from "node:http";

export async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  const body = Buffer.concat(chunks).toString("utf8");
  return body.length === 0 ? {} : JSON.parse(body);
}

export function sendJson(response: ServerResponse, statusCode: number, payload: unknown): void {
  const body = JSON.stringify(payload, null, 2);
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body),
    ...corsHeaders(),
  });
  response.end(body);
}

export function sendText(response: ServerResponse, statusCode: number, body: string, contentType = "text/plain; charset=utf-8"): void {
  response.writeHead(statusCode, {
    "content-type": contentType,
    "content-length": Buffer.byteLength(body),
    ...corsHeaders(),
  });
  response.end(body);
}

export async function serveStaticFile(response: ServerResponse, filePath: string): Promise<boolean> {
  if (!existsSync(filePath)) {
    return false;
  }

  const fileStat = await stat(filePath);
  if (!fileStat.isFile()) {
    return false;
  }

  response.writeHead(200, {
    "content-type": contentTypeFor(filePath),
    "content-length": fileStat.size,
    ...corsHeaders(),
  });
  createReadStream(filePath).pipe(response);
  return true;
}

export function sendError(response: ServerResponse, statusCode: number, message: string): void {
  sendJson(response, statusCode, { error: message });
}

export function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
  };
}

function contentTypeFor(filePath: string): string {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".html") {
    return "text/html; charset=utf-8";
  }
  if (extension === ".js") {
    return "application/javascript; charset=utf-8";
  }
  if (extension === ".css") {
    return "text/css; charset=utf-8";
  }
  if (extension === ".json") {
    return "application/json; charset=utf-8";
  }
  if (extension === ".svg") {
    return "image/svg+xml";
  }
  return "application/octet-stream";
}

