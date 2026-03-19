import { z } from "zod";

export const ProjectStatusSchema = z.enum(["idle", "indexing", "ready", "error"]);

export const IndexWarningSchema = z.object({
  code: z.string(),
  message: z.string(),
});

export const IndexRequestSchema = z.object({
  repoPath: z.string().min(1),
  projectName: z.string().trim().min(1).optional(),
});

export const StatsSchema = z.object({
  files: z.number().int().nonnegative(),
  symbols: z.number().int().nonnegative(),
  routes: z.number().int().nonnegative(),
  components: z.number().int().nonnegative(),
});

export const ProjectSummarySchema = z.object({
  projectId: z.string(),
  name: z.string(),
  repoPath: z.string(),
  status: ProjectStatusSchema,
  indexedAt: z.string().nullable(),
  stats: StatsSchema,
  warnings: z.array(IndexWarningSchema),
});

export const CitationSchema = z.object({
  filePath: z.string(),
  lineStart: z.number().int().positive(),
  lineEnd: z.number().int().positive(),
  symbolName: z.string().nullable(),
  excerpt: z.string(),
  reason: z.enum(["exact", "lexical", "graph", "heuristic"]),
});

export const ChatRequestSchema = z.object({
  question: z.string().trim().min(1),
  sessionId: z.string().trim().min(1).optional(),
});

export const ChatResponseSchema = z.object({
  sessionId: z.string(),
  answer: z.string(),
  citations: z.array(CitationSchema),
  diagnostics: z.object({
    strategy: z.string(),
    strongSignalBypass: z.boolean(),
    ftsQuery: z.string(),
  }),
});

export const GraphNodeSchema = z.object({
  id: z.string(),
  label: z.string(),
  type: z.string(),
  filePath: z.string().nullable(),
  symbolName: z.string().nullable(),
  metadata: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])).default({}),
});

export const GraphEdgeSchema = z.object({
  id: z.string(),
  source: z.string(),
  target: z.string(),
  type: z.string(),
  heuristic: z.boolean().default(false),
  metadata: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])).default({}),
});

export const GraphResponseSchema = z.object({
  nodes: z.array(GraphNodeSchema),
  edges: z.array(GraphEdgeSchema),
});

export const FileContentResponseSchema = z.object({
  filePath: z.string(),
  language: z.string(),
  content: z.string(),
  lineCount: z.number().int().nonnegative(),
});

export const PatchPreviewRequestSchema = z.object({
  filePath: z.string(),
  content: z.string(),
});

export const PatchPreviewResponseSchema = z.object({
  patch: z.string(),
  changed: z.boolean(),
});

export type ProjectStatus = z.infer<typeof ProjectStatusSchema>;
export type IndexWarning = z.infer<typeof IndexWarningSchema>;
export type IndexRequest = z.infer<typeof IndexRequestSchema>;
export type ProjectSummary = z.infer<typeof ProjectSummarySchema>;
export type Citation = z.infer<typeof CitationSchema>;
export type ChatRequest = z.infer<typeof ChatRequestSchema>;
export type ChatResponse = z.infer<typeof ChatResponseSchema>;
export type GraphNode = z.infer<typeof GraphNodeSchema>;
export type GraphEdge = z.infer<typeof GraphEdgeSchema>;
export type GraphResponse = z.infer<typeof GraphResponseSchema>;
export type FileContentResponse = z.infer<typeof FileContentResponseSchema>;
export type PatchPreviewRequest = z.infer<typeof PatchPreviewRequestSchema>;
export type PatchPreviewResponse = z.infer<typeof PatchPreviewResponseSchema>;

export type LanguageKind =
  | "java"
  | "typescript"
  | "tsx"
  | "javascript"
  | "jsx"
  | "vue"
  | "xml"
  | "json"
  | "sql"
  | "markdown"
  | "text"
  | "unknown";

export interface ScannedSourceFile {
  absolutePath: string;
  relativePath: string;
  language: LanguageKind;
  size: number;
  sha256: string;
  content: string;
  lineCount: number;
}

export interface ExtractedSymbol {
  symbolName: string;
  symbolType: string;
  filePath: string;
  lineStart: number;
  lineEnd: number;
  signature: string | null;
  heuristic: boolean;
}

export interface SpringRouteSignal {
  method: string;
  route: string;
  filePath: string;
  handlerSymbol: string | null;
  lineStart: number;
  lineEnd: number;
}

export interface ApiCallSignal {
  target: string;
  filePath: string;
  kind: string;
  lineStart: number;
  lineEnd: number;
}

export interface BuildDependencySignal {
  name: string;
  version: string | null;
  filePath: string;
}

export interface ImportSignal {
  source: string;
  filePath: string;
  lineStart: number;
  lineEnd: number;
}

export interface TreeSitterSummary {
  rootType: string;
  namedNodeCount: number;
  topKinds: Array<{ kind: string; count: number }>;
}

export interface IndexedFileArtifact extends ScannedSourceFile {
  imports: ImportSignal[];
  symbols: ExtractedSymbol[];
  routes: SpringRouteSignal[];
  apiCalls: ApiCallSignal[];
  buildDependencies: BuildDependencySignal[];
  componentName: string | null;
  treeSitterSummary: TreeSitterSummary | null;
  warnings: IndexWarning[];
  repoScore: number;
}

export interface SearchHit {
  filePath: string;
  lineStart: number;
  lineEnd: number;
  symbolName: string | null;
  excerpt: string;
  score: number;
  reason: Citation["reason"];
}

export interface SearchResult {
  hits: SearchHit[];
  strategy: string;
  strongSignalBypass: boolean;
  ftsQuery: string;
}

