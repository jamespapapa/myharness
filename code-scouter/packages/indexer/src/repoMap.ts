import type { IndexedFileArtifact } from "../../shared/src/index.js";

export interface RepoCardRow {
  summary: string;
  topEntriesJson: string;
}

export interface ModuleCardRow {
  moduleName: string;
  summary: string;
  score: number;
}

export interface FileCardRow {
  filePath: string;
  summary: string;
  score: number;
}

export interface SymbolCardRow {
  filePath: string;
  symbolName: string;
  lineStart: number;
  summary: string;
  score: number;
}

export function applyRepoScores(files: IndexedFileArtifact[]): IndexedFileArtifact[] {
  return files.map((file) => ({
    ...file,
    repoScore: scoreFile(file),
  }));
}

export function buildRepoCards(files: IndexedFileArtifact[]): {
  repoCard: RepoCardRow;
  moduleCards: ModuleCardRow[];
  fileCards: FileCardRow[];
  symbolCards: SymbolCardRow[];
} {
  const fileCards = files
    .map((file) => ({
      filePath: file.relativePath,
      summary: summarizeFile(file),
      score: file.repoScore,
    }))
    .sort((left, right) => right.score - left.score);

  const moduleMap = new Map<string, ModuleCardRow>();
  for (const file of files) {
    const moduleName = file.relativePath.includes("/") ? file.relativePath.split("/")[0]! : "(root)";
    const existing = moduleMap.get(moduleName);
    const increment = file.repoScore;
    if (!existing) {
      moduleMap.set(moduleName, {
        moduleName,
        summary: `Module ${moduleName} includes ${file.relativePath}.`,
        score: increment,
      });
      continue;
    }
    existing.score += increment;
  }

  const moduleCards = [...moduleMap.values()]
    .map((moduleCard) => ({
      ...moduleCard,
      score: Number(moduleCard.score.toFixed(2)),
      summary: `${moduleCard.moduleName} contains ${files.filter((file) => (file.relativePath.includes("/") ? file.relativePath.split("/")[0]! : "(root)") === moduleCard.moduleName).length} indexed files.`,
    }))
    .sort((left, right) => right.score - left.score);

  const symbolCards = files
    .flatMap((file) =>
      file.symbols.map((symbol) => ({
        filePath: file.relativePath,
        symbolName: symbol.symbolName,
        lineStart: symbol.lineStart,
        summary: `${symbol.symbolType} in ${file.relativePath}`,
        score: file.repoScore + (symbol.heuristic ? 0.25 : 1),
      })),
    )
    .sort((left, right) => right.score - left.score);

  const repoCard: RepoCardRow = {
    summary: `Indexed ${files.length} files with ${files.reduce((total, file) => total + file.symbols.length, 0)} symbols, ${files.reduce((total, file) => total + file.routes.length, 0)} routes, and ${files.reduce((total, file) => total + (file.componentName ? 1 : 0), 0)} Vue components.`,
    topEntriesJson: JSON.stringify(fileCards.slice(0, 12)),
  };

  return {
    repoCard,
    moduleCards,
    fileCards,
    symbolCards,
  };
}

function scoreFile(file: IndexedFileArtifact): number {
  let score = 1;
  score += file.imports.length * 0.7;
  score += file.symbols.length * 1.5;
  score += file.routes.length * 4;
  score += file.apiCalls.length * 2;
  score += file.buildDependencies.length * 1.5;
  score += file.componentName ? 3 : 0;
  score += file.treeSitterSummary ? 1 : 0;
  return Number(score.toFixed(2));
}

function summarizeFile(file: IndexedFileArtifact): string {
  const signals = [
    file.symbols.length > 0 ? `${file.symbols.length} symbols` : null,
    file.routes.length > 0 ? `${file.routes.length} routes` : null,
    file.apiCalls.length > 0 ? `${file.apiCalls.length} API calls` : null,
    file.buildDependencies.length > 0 ? `${file.buildDependencies.length} build dependencies` : null,
    file.componentName ? `Vue component ${file.componentName}` : null,
  ].filter(Boolean);

  if (signals.length === 0) {
    return `${file.language} file with lexical indexing only.`;
  }

  return `${file.language} file with ${signals.join(", ")}.`;
}

