import path from "node:path";
import { createRequire } from "node:module";

import {
  buildLineStarts,
  lineNumberFromOffset,
  type ApiCallSignal,
  type BuildDependencySignal,
  type ExtractedSymbol,
  type ImportSignal,
  type IndexWarning,
  type IndexedFileArtifact,
  type LanguageKind,
  type ScannedSourceFile,
  type SpringRouteSignal,
  type TreeSitterSummary,
} from "../../shared/src/index.js";

const require = createRequire(import.meta.url);

const TreeSitter = loadOptionalModule<typeof import("tree-sitter")>("tree-sitter");
const JavaLanguage = loadOptionalModule<any>("tree-sitter-java");
const TypeScriptLanguages = loadOptionalModule<{ typescript: any; tsx: any }>("tree-sitter-typescript");
const AstGrep = loadOptionalModule<any>("@ast-grep/napi");

export function extractFileArtifact(file: ScannedSourceFile): IndexedFileArtifact {
  const warnings: IndexWarning[] = [];
  const lineStarts = buildLineStarts(file.content);
  const imports = extractImports(file, lineStarts);
  const symbols = extractSymbols(file, lineStarts);
  const routes = extractSpringRoutes(file, lineStarts, symbols);
  const buildDependencies = extractBuildDependencies(file);
  const componentName = detectVueComponentName(file);
  const apiCalls = dedupeApiCalls([...extractApiCallsRegex(file, lineStarts), ...extractApiCallsAstGrep(file)]);
  const treeSitterSummary = buildTreeSitterSummary(file, warnings);

  return {
    ...file,
    imports,
    symbols,
    routes,
    apiCalls,
    buildDependencies,
    componentName,
    treeSitterSummary,
    warnings,
    repoScore: 0,
  };
}

function extractImports(file: ScannedSourceFile, lineStarts: number[]): ImportSignal[] {
  if (file.language === "java") {
    return collectMatches(/^\s*import\s+([\w.*]+);/gm, file.content, (match) => ({
      source: match[1]!,
      filePath: file.relativePath,
      lineStart: lineNumberFromOffset(lineStarts, match.index),
      lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
    }));
  }

  if (["typescript", "tsx", "javascript", "jsx", "vue"].includes(file.language)) {
    const scriptContext = file.language === "vue" ? extractVueScriptContext(file.content) : { script: file.content, lineOffset: 0 };
    const scriptStarts = buildLineStarts(scriptContext.script);
    return collectMatches(/^\s*import\s+.*?from\s+["']([^"']+)["'];?/gm, scriptContext.script, (match) => ({
      source: match[1]!,
      filePath: file.relativePath,
      lineStart: scriptContext.lineOffset + lineNumberFromOffset(scriptStarts, match.index),
      lineEnd: scriptContext.lineOffset + lineNumberFromOffset(scriptStarts, match.index + match[0].length),
    }));
  }

  return [];
}

function extractSymbols(file: ScannedSourceFile, lineStarts: number[]): ExtractedSymbol[] {
  if (file.language === "java") {
    return [...extractJavaTypeSymbols(file, lineStarts), ...extractJavaMethodSymbols(file, lineStarts)];
  }

  if (["typescript", "tsx", "javascript", "jsx"].includes(file.language)) {
    return extractTsLikeSymbols(file.relativePath, file.content, lineStarts);
  }

  if (file.language === "vue") {
    const scriptContext = extractVueScriptContext(file.content);
    const baseSymbols = extractTsLikeSymbols(file.relativePath, scriptContext.script, buildLineStarts(scriptContext.script)).map((symbol) => ({
      ...symbol,
      lineStart: symbol.lineStart + scriptContext.lineOffset,
      lineEnd: symbol.lineEnd + scriptContext.lineOffset,
    }));
    const componentName = detectVueComponentName(file);
    const componentSymbols = componentName
      ? [
          {
            symbolName: componentName,
            symbolType: "VueComponent",
            filePath: file.relativePath,
            lineStart: 1,
            lineEnd: Math.max(1, file.lineCount),
            signature: `<script> component ${componentName}`,
            heuristic: true,
          },
        ]
      : [];
    return [...componentSymbols, ...baseSymbols];
  }

  return [];
}

function extractJavaTypeSymbols(file: ScannedSourceFile, lineStarts: number[]): ExtractedSymbol[] {
  return collectMatches(
    /((?:@\w+(?:\([^)]*\))?\s*)*)(?:public\s+|protected\s+|private\s+)?(?:abstract\s+)?(class|interface|enum|record)\s+([A-Za-z_]\w*)/g,
    file.content,
    (match) => {
      const annotationBlock = match[1] ?? "";
      let symbolType = normalizeJavaType(match[2]!, annotationBlock);
      return {
        symbolName: match[3]!,
        symbolType,
        filePath: file.relativePath,
        lineStart: lineNumberFromOffset(lineStarts, match.index),
        lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
        signature: match[0].trim(),
        heuristic: false,
      };
    },
  );
}

function extractJavaMethodSymbols(file: ScannedSourceFile, lineStarts: number[]): ExtractedSymbol[] {
  return collectMatches(
    /(?:public|protected|private)\s+(?:static\s+)?(?:final\s+)?(?:[\w<>\[\], ?]+\s+)+([a-zA-Z_]\w*)\s*\(([^)]*)\)\s*\{/g,
    file.content,
    (match) => ({
      symbolName: match[1]!,
      symbolType: "Method",
      filePath: file.relativePath,
      lineStart: lineNumberFromOffset(lineStarts, match.index),
      lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
      signature: `${match[1]}(${match[2] ?? ""})`,
      heuristic: false,
    }),
  );
}

function normalizeJavaType(kind: string, annotations: string): string {
  if (/RestController|Controller/.test(annotations)) {
    return "SpringController";
  }
  if (/Service/.test(annotations)) {
    return "Service";
  }
  if (/Repository/.test(annotations)) {
    return "Repository";
  }
  if (/Entity/.test(annotations)) {
    return "Entity";
  }
  if (kind === "interface") {
    return "Interface";
  }
  return "Class";
}

function extractTsLikeSymbols(filePath: string, content: string, lineStarts: number[]): ExtractedSymbol[] {
  const functionSymbols = collectMatches(
    /(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/g,
    content,
    (match) => ({
      symbolName: match[1]!,
      symbolType: "Function",
      filePath,
      lineStart: lineNumberFromOffset(lineStarts, match.index),
      lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
      signature: `${match[1]}(${match[2] ?? ""})`,
      heuristic: false,
    }),
  );

  const classSymbols = collectMatches(/(?:export\s+)?class\s+([A-Za-z_]\w*)/g, content, (match) => ({
    symbolName: match[1]!,
    symbolType: "Class",
    filePath,
    lineStart: lineNumberFromOffset(lineStarts, match.index),
    lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
    signature: match[0].trim(),
    heuristic: false,
  }));

  const constSymbols = collectMatches(
    /(?:export\s+)?const\s+([A-Za-z_]\w*)\s*=\s*(?:async\s+)?(?:\([^)]*\)|[A-Za-z_]\w*)\s*=>/g,
    content,
    (match) => ({
      symbolName: match[1]!,
      symbolType: "Function",
      filePath,
      lineStart: lineNumberFromOffset(lineStarts, match.index),
      lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
      signature: match[0].trim(),
      heuristic: true,
    }),
  );

  return [...classSymbols, ...functionSymbols, ...constSymbols];
}

function extractSpringRoutes(
  file: ScannedSourceFile,
  lineStarts: number[],
  symbols: ExtractedSymbol[],
): SpringRouteSignal[] {
  if (file.language !== "java") {
    return [];
  }

  return collectMatches(
    /@((Get|Post|Put|Delete|Patch)Mapping|RequestMapping)\s*(\(([^)]*)\))?/g,
    file.content,
    (match) => {
      const routeArgs = match[4] ?? "";
      const explicitPath = /["']([^"']+)["']/.exec(routeArgs)?.[1] ?? "/";
      const method = match[2] ?? /RequestMethod\.([A-Z]+)/.exec(routeArgs)?.[1] ?? "REQUEST";
      const annotationLine = lineNumberFromOffset(lineStarts, match.index);
      const handler = symbols.find((symbol) => symbol.symbolType === "Method" && symbol.lineStart >= annotationLine);
      return {
        method,
        route: explicitPath,
        filePath: file.relativePath,
        handlerSymbol: handler?.symbolName ?? null,
        lineStart: annotationLine,
        lineEnd: lineNumberFromOffset(lineStarts, match.index + match[0].length),
      };
    },
  );
}

function extractBuildDependencies(file: ScannedSourceFile): BuildDependencySignal[] {
  if (file.relativePath.endsWith("pom.xml")) {
    return collectMatches(
      /<dependency>[\s\S]*?<artifactId>([^<]+)<\/artifactId>[\s\S]*?(?:<version>([^<]+)<\/version>)?[\s\S]*?<\/dependency>/g,
      file.content,
      (match) => ({
        name: match[1]!,
        version: match[2] ?? null,
        filePath: file.relativePath,
      }),
    );
  }

  if (file.relativePath.endsWith("package.json")) {
    try {
      const parsed = JSON.parse(file.content) as { dependencies?: Record<string, string>; devDependencies?: Record<string, string> };
      const merged = { ...parsed.dependencies, ...parsed.devDependencies };
      return Object.entries(merged).map(([name, version]) => ({
        name,
        version,
        filePath: file.relativePath,
      }));
    } catch {
      return [];
    }
  }

  return [];
}

function detectVueComponentName(file: ScannedSourceFile): string | null {
  if (file.language !== "vue") {
    return null;
  }

  const directName = /name:\s*["']([^"']+)["']/.exec(file.content)?.[1];
  if (directName) {
    return directName;
  }
  return path.basename(file.relativePath, ".vue");
}

function extractApiCallsRegex(file: ScannedSourceFile, lineStarts: number[]): ApiCallSignal[] {
  const scriptContext = file.language === "vue" ? extractVueScriptContext(file.content) : { script: file.content, lineOffset: 0 };
  const content = scriptContext.script;
  const effectiveLineStarts = file.language === "vue" ? buildLineStarts(content) : lineStarts;
  if (!["typescript", "tsx", "javascript", "jsx", "vue"].includes(file.language)) {
    return [];
  }

  return collectMatches(
    /(fetch|axios\.(?:get|post|put|delete|patch)|\$axios|\$http)\s*\(\s*["'`]([^"'`]+)["'`]/g,
    content,
    (match) => ({
      target: match[2]!,
      filePath: file.relativePath,
      kind: match[1]!,
      lineStart: scriptContext.lineOffset + lineNumberFromOffset(effectiveLineStarts, match.index),
      lineEnd: scriptContext.lineOffset + lineNumberFromOffset(effectiveLineStarts, match.index + match[0].length),
    }),
  );
}

function extractApiCallsAstGrep(file: ScannedSourceFile): ApiCallSignal[] {
  if (!AstGrep || !["typescript", "tsx", "javascript", "jsx", "vue"].includes(file.language)) {
    return [];
  }

  try {
    const scriptContext = file.language === "vue" ? extractVueScriptContext(file.content) : { script: file.content, lineOffset: 0 };
    const content = scriptContext.script;
    const parser = file.language === "tsx" || file.language === "jsx" ? AstGrep.tsx : AstGrep.ts;
    const root = parser.parse(content);
    const matches = root.root().findAll(parser.kind("call_expression")) as Array<{ text(): string; range(): { start: { line: number }; end: { line: number } } }>;

    return matches
      .map((node) => node.text())
      .filter((text) => /(fetch|axios\.|\$axios|\$http)/.test(text))
      .map((text) => {
        const target = /["'`]([^"'`]+)["'`]/.exec(text)?.[1] ?? "unknown";
        const lineStart = scriptContext.lineOffset + content.slice(0, content.indexOf(text)).split(/\r?\n/).length;
        return {
          target,
          filePath: file.relativePath,
          kind: "ast-grep-call",
          lineStart,
          lineEnd: lineStart,
        };
      });
  } catch {
    return [];
  }
}

function dedupeApiCalls(calls: ApiCallSignal[]): ApiCallSignal[] {
  const seen = new Set<string>();
  return calls.filter((call) => {
    const key = `${call.filePath}:${call.lineStart}:${call.target}:${call.kind}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function buildTreeSitterSummary(file: ScannedSourceFile, warnings: IndexWarning[]): TreeSitterSummary | null {
  if (!TreeSitter) {
    return null;
  }

  if (file.language === "vue") {
    const scriptContext = extractVueScriptContext(file.content);
    const vueScriptLanguage = TypeScriptLanguages?.tsx ?? TypeScriptLanguages?.typescript ?? null;
    if (!vueScriptLanguage) {
      return {
        rootType: "vue_sfc",
        namedNodeCount: 0,
        topKinds: [],
      };
    }
    return summarizeTree(file.relativePath, scriptContext.script, vueScriptLanguage, warnings, "vue_sfc");
  }

  const language = resolveTreeSitterLanguage(file.language);
  if (!language) {
    return null;
  }

  return summarizeTree(file.relativePath, file.content, language, warnings);
}

function resolveTreeSitterLanguage(language: LanguageKind): unknown {
  if (language === "java") {
    return JavaLanguage;
  }
  if (language === "typescript" || language === "javascript") {
    return TypeScriptLanguages?.typescript;
  }
  if (language === "tsx" || language === "jsx") {
    return TypeScriptLanguages?.tsx;
  }
  return null;
}

function extractVueScriptContext(content: string): { script: string; lineOffset: number } {
  const match = /<script[^>]*>([\s\S]*?)<\/script>/i.exec(content);
  if (!match) {
    return { script: "", lineOffset: 0 };
  }

  const script = match[1] ?? "";
  const prefix = content.slice(0, match.index);
  const openingTag = /<script[^>]*>/i.exec(content.slice(match.index, match.index + match[0].length))?.[0] ?? "<script>";
  const lineOffset = prefix.split(/\r?\n/).length + openingTag.split(/\r?\n/).length - 1;
  return { script, lineOffset };
}

function collectMatches<T>(regex: RegExp, content: string, mapMatch: (match: RegExpExecArray) => T): T[] {
  const matches: T[] = [];
  regex.lastIndex = 0;
  let match = regex.exec(content);
  while (match) {
    matches.push(mapMatch(match));
    if (regex.lastIndex === match.index) {
      regex.lastIndex += 1;
    }
    match = regex.exec(content);
  }
  return matches;
}

function loadOptionalModule<T>(moduleName: string): T | null {
  try {
    return require(moduleName) as T;
  } catch {
    return null;
  }
}

function summarizeTree(
  filePath: string,
  content: string,
  language: unknown,
  warnings: IndexWarning[],
  rootTypeOverride?: string,
): TreeSitterSummary | null {
  if (!TreeSitter) {
    return null;
  }
  try {
    const parser = new TreeSitter();
    parser.setLanguage(language as any);
    const tree = parser.parse(content);
    const queue = [tree.rootNode];
    const kindCounts = new Map<string, number>();
    let namedNodeCount = 0;

    while (queue.length > 0 && namedNodeCount < 2_000) {
      const node = queue.pop()!;
      if (node.isNamed) {
        namedNodeCount += 1;
        kindCounts.set(node.type, (kindCounts.get(node.type) ?? 0) + 1);
      }
      for (let index = node.namedChildCount - 1; index >= 0; index -= 1) {
        const child = node.namedChild(index);
        if (child) {
          queue.push(child);
        }
      }
    }

    return {
      rootType: rootTypeOverride ?? tree.rootNode.type,
      namedNodeCount,
      topKinds: [...kindCounts.entries()]
        .sort((left, right) => right[1] - left[1])
        .slice(0, 8)
        .map(([kind, count]) => ({ kind, count })),
    };
  } catch (error) {
    warnings.push({
      code: "treesitter.parse_failed",
      message: `Tree-sitter failed for ${filePath}: ${error instanceof Error ? error.message : String(error)}`,
    });
    return null;
  }
}
