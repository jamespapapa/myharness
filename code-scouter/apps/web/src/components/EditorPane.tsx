import { useEffect, useRef } from "react";

import { Editor, loader, type OnMount } from "@monaco-editor/react";
import * as monaco from "monaco-editor";

loader.config({ monaco });

interface EditorFileState {
  filePath: string;
  language: string;
  content: string;
  originalContent: string;
  lineStart: number;
  lineEnd: number;
}

interface EditorPaneProps {
  fileState: EditorFileState | null;
  patchPreview: string;
  onChangeContent: (content: string) => void;
  onRequestPatchPreview: () => void;
}

export function EditorPane(props: EditorPaneProps) {
  const { fileState, patchPreview, onChangeContent, onRequestPatchPreview } = props;
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  const decorationIds = useRef<string[]>([]);

  const handleMount: OnMount = (editorInstance) => {
    editorRef.current = editorInstance;
  };

  useEffect(() => {
    if (!fileState || !editorRef.current) {
      return;
    }

    const range = new monaco.Range(fileState.lineStart, 1, fileState.lineEnd, 1);
    decorationIds.current = editorRef.current.deltaDecorations(decorationIds.current, [
      {
        range,
        options: {
          isWholeLine: true,
          className: "editor-highlight",
        },
      },
    ]);
    editorRef.current.revealLineInCenter(fileState.lineStart);
  }, [fileState]);

  return (
    <section className="panel editor-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Editor</p>
          <h2>{fileState ? fileState.filePath : "Select a citation to inspect code"}</h2>
        </div>
        <button className="ghost-button" disabled={!fileState} onClick={onRequestPatchPreview} type="button">
          Preview Patch
        </button>
      </div>

      {fileState ? (
        <>
          <Editor
            height="420px"
            language={normalizeMonacoLanguage(fileState.language)}
            onChange={(value: string | undefined) => onChangeContent(value ?? "")}
            onMount={handleMount}
            options={{
              automaticLayout: true,
              fontFamily: "Cascadia Code, Fira Code, monospace",
              fontSize: 13,
              minimap: { enabled: false },
              scrollBeyondLastLine: false,
            }}
            value={fileState.content}
          />
          <div className="patch-preview">
            <div className="subpanel-header">
              <span>Patch Preview</span>
              <span>{fileState.content === fileState.originalContent ? "No local edits" : "Local edits pending"}</span>
            </div>
            <pre>{patchPreview || "Edit the file in Monaco and request a preview to see a synthetic unified diff."}</pre>
          </div>
        </>
      ) : (
        <div className="empty-state">
          Open a citation from chat or a graph node with a file path to inspect the indexed source.
        </div>
      )}
    </section>
  );
}

function normalizeMonacoLanguage(language: string): string {
  if (language === "vue") {
    return "html";
  }
  if (language === "java") {
    return "java";
  }
  if (language === "typescript" || language === "tsx") {
    return "typescript";
  }
  if (language === "javascript" || language === "jsx") {
    return "javascript";
  }
  if (language === "json") {
    return "json";
  }
  if (language === "sql") {
    return "sql";
  }
  if (language === "xml") {
    return "xml";
  }
  return "plaintext";
}
