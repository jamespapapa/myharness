import { startTransition, useEffect, useMemo, useState } from "react";

import { EditorPane } from "./components/EditorPane.js";
import { GraphPanel } from "./components/GraphPanel.js";
import type {
  ChatResponse,
  Citation,
  FileContentResponse,
  GraphResponse,
  ProjectSummary,
} from "../../../packages/shared/src/index.js";

type TabId = "index" | "chat" | "graph";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  citations?: Citation[];
}

interface EditorFileState {
  filePath: string;
  language: string;
  content: string;
  originalContent: string;
  lineStart: number;
  lineEnd: number;
}

export function App() {
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [selectedProjectId, setSelectedProjectId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabId>("index");
  const [repoPathInput, setRepoPathInput] = useState("");
  const [projectNameInput, setProjectNameInput] = useState("");
  const [statusLine, setStatusLine] = useState("Ready for first-time indexing.");
  const [isIndexing, setIsIndexing] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [question, setQuestion] = useState("");
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [editorFile, setEditorFile] = useState<EditorFileState | null>(null);
  const [patchPreview, setPatchPreview] = useState("");
  const [graph, setGraph] = useState<GraphResponse | null>(null);

  const selectedProject = useMemo(
    () => projects.find((project) => project.projectId === selectedProjectId) ?? null,
    [projects, selectedProjectId],
  );

  useEffect(() => {
    void loadProjects();
  }, []);

  useEffect(() => {
    if (!selectedProjectId) {
      setGraph(null);
      return;
    }

    void fetch(`/api/projects/${selectedProjectId}/graph`)
      .then((response) => response.json())
      .then((payload: GraphResponse) => {
        startTransition(() => {
          setGraph(payload);
        });
      })
      .catch(() => {
        setGraph(null);
      });
  }, [selectedProjectId]);

  async function loadProjects(): Promise<void> {
    const response = await fetch("/api/projects");
    const payload = (await response.json()) as { projects: ProjectSummary[] };
    startTransition(() => {
      setProjects(payload.projects);
      setSelectedProjectId((current) => current ?? payload.projects[0]?.projectId ?? null);
    });
  }

  async function handleIndex(): Promise<void> {
    setIsIndexing(true);
    setStatusLine("Indexing local repository into SQLite...");
    try {
      const response = await fetch("/api/projects/index", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          repoPath: repoPathInput,
          projectName: projectNameInput || undefined,
        }),
      });

      if (!response.ok) {
        const error = (await response.json()) as { error: string };
        throw new Error(error.error);
      }

      const payload = (await response.json()) as { project: ProjectSummary };
      await loadProjects();
      startTransition(() => {
        setSelectedProjectId(payload.project.projectId);
        setActiveTab("chat");
        setStatusLine(`Indexed ${payload.project.stats.files} files for ${payload.project.name}.`);
      });
    } catch (error) {
      setStatusLine(error instanceof Error ? error.message : "Indexing failed.");
    } finally {
      setIsIndexing(false);
    }
  }

  async function handleAsk(): Promise<void> {
    if (!selectedProjectId || question.trim().length === 0) {
      return;
    }

    const userMessage: ChatMessage = { role: "user", content: question };
    setMessages((current) => [...current, userMessage]);

    const response = await fetch(`/api/projects/${selectedProjectId}/chat`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        question,
        sessionId: sessionId ?? undefined,
      }),
    });

    const payload = (await response.json()) as ChatResponse | { error: string };
    if (!response.ok || "error" in payload) {
      setMessages((current) => [
        ...current,
        {
          role: "assistant",
          content: "The local chat request failed.",
        },
      ]);
      return;
    }

    setQuestion("");
    setSessionId(payload.sessionId);
    setMessages((current) => [
      ...current,
      {
        role: "assistant",
        content: payload.answer,
        citations: payload.citations,
      },
    ]);
  }

  async function openCitation(citation: Citation): Promise<void> {
    await openFile(citation.filePath, citation.lineStart, citation.lineEnd);
  }

  async function openFile(filePath: string, lineStart = 1, lineEnd = 1): Promise<void> {
    if (!selectedProjectId) {
      return;
    }
    const response = await fetch(`/api/projects/${selectedProjectId}/files/content?path=${encodeURIComponent(filePath)}`);
    const payload = (await response.json()) as FileContentResponse;
    startTransition(() => {
      setEditorFile({
        filePath: payload.filePath,
        language: payload.language,
        content: payload.content,
        originalContent: payload.content,
        lineStart,
        lineEnd,
      });
      setPatchPreview("");
    });
  }

  async function previewPatch(): Promise<void> {
    if (!editorFile || !selectedProjectId) {
      return;
    }

    const response = await fetch(`/api/projects/${selectedProjectId}/patch-preview`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        filePath: editorFile.filePath,
        content: editorFile.content,
      }),
    });
    const payload = (await response.json()) as { patch: string };
    setPatchPreview(payload.patch);
  }

  function updateEditorContent(content: string): void {
    setEditorFile((current) => (current ? { ...current, content } : current));
  }

  return (
    <div className="app-shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Offline-First Repository Analysis</p>
          <h1>Code Scouter Control Room</h1>
          <p className="hero-copy">
            Deterministic indexing, grounded chat, Monaco code inspection, and ontology browsing for closed-network Windows environments.
          </p>
        </div>
        <div className="hero-status">
          <label>
            Active project
            <select onChange={(event) => setSelectedProjectId(event.target.value)} value={selectedProjectId ?? ""}>
              <option value="" disabled>
                Select indexed project
              </option>
              {projects.map((project) => (
                <option key={project.projectId} value={project.projectId}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          <p>{statusLine}</p>
        </div>
      </header>

      <nav className="tab-strip">
        {(["index", "chat", "graph"] as TabId[]).map((tab) => (
          <button
            className={tab === activeTab ? "tab-button active" : "tab-button"}
            key={tab}
            onClick={() => setActiveTab(tab)}
            type="button"
          >
            {tab}
          </button>
        ))}
      </nav>

      <main className="workspace">
        <section className="workspace-main">
          {activeTab === "index" ? (
            <section className="panel">
              <div className="panel-header">
                <div>
                  <p className="eyebrow">Index</p>
                  <h2>First-Time Repository Index</h2>
                </div>
                <button className="primary-button" disabled={isIndexing || repoPathInput.trim().length === 0} onClick={() => void handleIndex()} type="button">
                  {isIndexing ? "Indexing..." : "Start Index"}
                </button>
              </div>

              <div className="form-grid">
                <label>
                  Repository path
                  <input onChange={(event) => setRepoPathInput(event.target.value)} placeholder="C:\\repos\\sample-app or /Users/me/repo" value={repoPathInput} />
                </label>
                <label>
                  Project name
                  <input onChange={(event) => setProjectNameInput(event.target.value)} placeholder="Optional display name" value={projectNameInput} />
                </label>
              </div>

              <div className="stats-grid">
                <StatCard label="Indexed files" value={selectedProject?.stats.files ?? 0} />
                <StatCard label="Symbols" value={selectedProject?.stats.symbols ?? 0} />
                <StatCard label="Routes" value={selectedProject?.stats.routes ?? 0} />
                <StatCard label="Vue components" value={selectedProject?.stats.components ?? 0} />
              </div>

              <div className="warning-list">
                {(selectedProject?.warnings ?? []).slice(0, 6).map((warning) => (
                  <article key={`${warning.code}:${warning.message}`} className="warning-item">
                    <strong>{warning.code}</strong>
                    <span>{warning.message}</span>
                  </article>
                ))}
              </div>
            </section>
          ) : null}

          {activeTab === "chat" ? (
            <section className="panel chat-panel">
              <div className="panel-header">
                <div>
                  <p className="eyebrow">Chat</p>
                  <h2>Grounded Repository Analysis</h2>
                </div>
                <span className="muted">{selectedProject ? selectedProject.name : "Index a project first"}</span>
              </div>

              <div className="message-list">
                {messages.length === 0 ? (
                  <div className="empty-state">Ask about a route, class, component, build dependency, or API call after indexing.</div>
                ) : (
                  messages.map((message, index) => (
                    <article className={`message-bubble ${message.role}`} key={`${message.role}-${index}`}>
                      <p>{message.content}</p>
                      {message.citations?.length ? (
                        <div className="citation-list">
                          {message.citations.map((citation) => (
                            <button className="citation-pill" key={`${citation.filePath}:${citation.lineStart}:${citation.lineEnd}`} onClick={() => void openCitation(citation)} type="button">
                              {citation.filePath}:{citation.lineStart}-{citation.lineEnd}
                            </button>
                          ))}
                        </div>
                      ) : null}
                    </article>
                  ))
                )}
              </div>

              <div className="chat-compose">
                <textarea
                  onChange={(event) => setQuestion(event.target.value)}
                  placeholder="Ask about a route, symbol, data flow, or frontend-backend linkage."
                  value={question}
                />
                <button className="primary-button" disabled={!selectedProjectId || question.trim().length === 0} onClick={() => void handleAsk()} type="button">
                  Ask
                </button>
              </div>
            </section>
          ) : null}

          {activeTab === "graph" ? <GraphPanel graph={graph} onOpenFile={(filePath, lineStart, lineEnd) => void openFile(filePath, lineStart, lineEnd)} /> : null}
        </section>

        <EditorPane
          fileState={editorFile}
          onChangeContent={updateEditorContent}
          onRequestPatchPreview={() => void previewPatch()}
          patchPreview={patchPreview}
        />
      </main>
    </div>
  );
}

function StatCard(props: { label: string; value: number }) {
  return (
    <article className="stat-card">
      <span>{props.label}</span>
      <strong>{props.value}</strong>
    </article>
  );
}

