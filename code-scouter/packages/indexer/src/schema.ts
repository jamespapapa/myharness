import type { DatabaseSync } from "node:sqlite";

export function initializeProjectSchema(db: DatabaseSync): void {
  db.exec(`
    create table if not exists projects (
      project_id text primary key,
      name text not null,
      repo_path text not null,
      status text not null,
      created_at text not null,
      updated_at text not null,
      indexed_at text
    );

    create table if not exists index_runs (
      run_id text primary key,
      project_id text not null,
      status text not null,
      started_at text not null,
      finished_at text,
      indexed_files integer default 0,
      warnings_json text not null default '[]'
    );

    create table if not exists scan_files (
      project_id text not null,
      file_path text not null,
      sha256 text not null,
      size integer not null,
      language text not null,
      primary key (project_id, file_path)
    );

    create table if not exists files (
      project_id text not null,
      file_path text not null,
      language text not null,
      sha256 text not null,
      size integer not null,
      line_count integer not null,
      content text not null,
      primary key (project_id, file_path)
    );

    create table if not exists symbols (
      project_id text not null,
      file_path text not null,
      symbol_name text not null,
      symbol_type text not null,
      line_start integer not null,
      line_end integer not null,
      signature text,
      heuristic integer not null default 0
    );

    create table if not exists imports (
      project_id text not null,
      file_path text not null,
      source text not null,
      line_start integer not null,
      line_end integer not null
    );

    create table if not exists spring_routes (
      project_id text not null,
      file_path text not null,
      method text not null,
      route text not null,
      handler_symbol text,
      line_start integer not null,
      line_end integer not null
    );

    create table if not exists api_calls (
      project_id text not null,
      file_path text not null,
      target text not null,
      kind text not null,
      line_start integer not null,
      line_end integer not null
    );

    create table if not exists vue_components (
      project_id text not null,
      file_path text not null,
      component_name text not null,
      line_start integer not null,
      line_end integer not null
    );

    create table if not exists build_dependencies (
      project_id text not null,
      file_path text not null,
      dependency_name text not null,
      version text
    );

    create table if not exists repo_cards (
      project_id text primary key,
      summary text not null,
      top_entries_json text not null
    );

    create table if not exists module_cards (
      project_id text not null,
      module_name text not null,
      summary text not null,
      score real not null,
      primary key (project_id, module_name)
    );

    create table if not exists file_cards (
      project_id text not null,
      file_path text not null,
      summary text not null,
      score real not null,
      primary key (project_id, file_path)
    );

    create table if not exists symbol_cards (
      project_id text not null,
      file_path text not null,
      symbol_name text not null,
      line_start integer not null,
      summary text not null,
      score real not null,
      primary key (project_id, file_path, symbol_name, line_start)
    );

    create table if not exists ontology_nodes (
      node_id text primary key,
      project_id text not null,
      label text not null,
      node_type text not null,
      file_path text,
      symbol_name text,
      metadata_json text not null
    );

    create table if not exists ontology_edges (
      edge_id text primary key,
      project_id text not null,
      source_id text not null,
      target_id text not null,
      edge_type text not null,
      heuristic integer not null default 0,
      metadata_json text not null
    );

    create virtual table if not exists fts_documents using fts5(
      project_id unindexed,
      file_path unindexed,
      symbol_name unindexed,
      line_start unindexed,
      line_end unindexed,
      chunk_text
    );

    create table if not exists vec_chunks (
      project_id text not null,
      file_path text not null,
      line_start integer not null,
      line_end integer not null,
      chunk_text text not null,
      embedding_json text
    );

    create table if not exists chat_sessions (
      session_id text primary key,
      project_id text not null,
      title text not null,
      created_at text not null,
      updated_at text not null
    );

    create table if not exists chat_messages (
      message_id text primary key,
      session_id text not null,
      role text not null,
      content text not null,
      created_at text not null
    );

    create table if not exists evidence_sets (
      evidence_id text primary key,
      message_id text not null,
      citations_json text not null
    );

    create index if not exists idx_symbols_project on symbols (project_id, file_path);
    create index if not exists idx_routes_project on spring_routes (project_id, file_path);
    create index if not exists idx_api_calls_project on api_calls (project_id, file_path);
    create index if not exists idx_ontology_nodes_project on ontology_nodes (project_id, node_type);
    create index if not exists idx_ontology_edges_project on ontology_edges (project_id, edge_type);
  `);
}

export function clearProjectData(db: DatabaseSync, projectId: string): void {
  const tables = [
    "scan_files",
    "files",
    "symbols",
    "imports",
    "spring_routes",
    "api_calls",
    "vue_components",
    "build_dependencies",
    "repo_cards",
    "module_cards",
    "file_cards",
    "symbol_cards",
    "ontology_nodes",
    "ontology_edges",
    "vec_chunks",
  ];

  for (const table of tables) {
    db.prepare(`delete from ${table} where project_id = ?`).run(projectId);
  }

  db.prepare("delete from fts_documents where project_id = ?").run(projectId);
}
