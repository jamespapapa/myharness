import { useDeferredValue, useEffect, useMemo, useRef, useState } from "react";

import cytoscape from "cytoscape";

import type { GraphResponse } from "../../../../packages/shared/src/index.js";

interface GraphPanelProps {
  graph: GraphResponse | null;
  onOpenFile: (filePath: string, lineStart?: number, lineEnd?: number) => void;
}

export function GraphPanel(props: GraphPanelProps) {
  const { graph, onOpenFile } = props;
  const [search, setSearch] = useState("");
  const [nodeTypeFilter, setNodeTypeFilter] = useState("all");
  const [edgeTypeFilter, setEdgeTypeFilter] = useState("all");
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const deferredSearch = useDeferredValue(search);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const cyRef = useRef<cytoscape.Core | null>(null);

  const filteredGraph = useMemo(() => {
    if (!graph) {
      return null;
    }

    const matchingNodes = graph.nodes.filter((node) => {
      const matchesType = nodeTypeFilter === "all" || node.type === nodeTypeFilter;
      const matchesSearch =
        deferredSearch.trim().length === 0 ||
        node.label.toLowerCase().includes(deferredSearch.toLowerCase()) ||
        node.filePath?.toLowerCase().includes(deferredSearch.toLowerCase());
      return matchesType && matchesSearch;
    });

    const allowedNodeIds = new Set(matchingNodes.map((node) => node.id));
    const matchingEdges = graph.edges.filter((edge) => {
      const matchesType = edgeTypeFilter === "all" || edge.type === edgeTypeFilter;
      return matchesType && allowedNodeIds.has(edge.source) && allowedNodeIds.has(edge.target);
    });

    return { nodes: matchingNodes, edges: matchingEdges };
  }, [deferredSearch, edgeTypeFilter, graph, nodeTypeFilter]);

  useEffect(() => {
    if (!containerRef.current || !filteredGraph) {
      return;
    }

    const elements: cytoscape.ElementDefinition[] = [
      ...filteredGraph.nodes.map((node) => ({
        data: {
          id: node.id,
          label: node.label,
          type: node.type,
        },
      })),
      ...filteredGraph.edges.map((edge) => ({
        data: {
          id: edge.id,
          source: edge.source,
          target: edge.target,
          label: edge.type,
        },
      })),
    ];

    cyRef.current?.destroy();
    const cy = cytoscape({
      container: containerRef.current,
      elements,
      layout: {
        name: "cose",
        animate: false,
      },
      style: [
        {
          selector: "node",
          style: {
            label: "data(label)",
            "font-size": 10,
            "background-color": "#2f7a67",
            color: "#f8f3e8",
            "text-wrap": "wrap",
            "text-max-width": "110px",
            "border-width": 2,
            "border-color": "#f0c989",
          },
        },
        {
          selector: "edge",
          style: {
            label: "data(label)",
            "font-size": 8,
            width: 1.5,
            "line-color": "#8ba59d",
            "target-arrow-color": "#8ba59d",
            "target-arrow-shape": "triangle",
            "curve-style": "bezier",
          },
        },
        {
          selector: ".selected",
          style: {
            "background-color": "#f26d4b",
            "border-color": "#f8f3e8",
            "border-width": 3,
          },
        },
      ],
    });

    cy.on("tap", "node", (event) => {
      const nodeId = event.target.id();
      setSelectedNodeId(nodeId);
      cy.elements().removeClass("selected");
      event.target.addClass("selected");
    });

    cyRef.current = cy;
    return () => cy.destroy();
  }, [filteredGraph]);

  const selectedNode = filteredGraph?.nodes.find((node) => node.id === selectedNodeId) ?? null;
  const nodeTypes = graph ? ["all", ...new Set(graph.nodes.map((node) => node.type))] : ["all"];
  const edgeTypes = graph ? ["all", ...new Set(graph.edges.map((edge) => edge.type))] : ["all"];

  return (
    <section className="panel graph-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Graph</p>
          <h2>Ontology Viewer</h2>
        </div>
        <div className="graph-filters">
          <input onChange={(event) => setSearch(event.target.value)} placeholder="Search nodes or paths" value={search} />
          <select onChange={(event) => setNodeTypeFilter(event.target.value)} value={nodeTypeFilter}>
            {nodeTypes.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
          <select onChange={(event) => setEdgeTypeFilter(event.target.value)} value={edgeTypeFilter}>
            {edgeTypes.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="graph-layout">
        <div className="graph-canvas" ref={containerRef} />
        <aside className="graph-detail">
          {selectedNode ? (
            <>
              <h3>{selectedNode.label}</h3>
              <p>{selectedNode.type}</p>
              {selectedNode.filePath ? <p>{selectedNode.filePath}</p> : null}
              <dl>
                {Object.entries(selectedNode.metadata).map(([key, value]) => (
                  <div key={key}>
                    <dt>{key}</dt>
                    <dd>{String(value)}</dd>
                  </div>
                ))}
              </dl>
              {selectedNode.filePath ? (
                <button
                  className="ghost-button"
                  onClick={() =>
                    onOpenFile(
                      selectedNode.filePath!,
                      typeof selectedNode.metadata.lineStart === "number" ? selectedNode.metadata.lineStart : 1,
                      typeof selectedNode.metadata.lineEnd === "number" ? selectedNode.metadata.lineEnd : 1,
                    )
                  }
                  type="button"
                >
                  Open in Monaco
                </button>
              ) : null}
            </>
          ) : (
            <div className="empty-state">Pick a node to inspect its details and linked code.</div>
          )}
        </aside>
      </div>
    </section>
  );
}
