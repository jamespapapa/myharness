#!/usr/bin/env bash

set -euo pipefail

harness_repo_root() {
  local script_dir common_git_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if common_git_dir=$(git -C "$script_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    dirname "$common_git_dir"
    return 0
  fi

  git -C "$script_dir" rev-parse --show-toplevel
}

harness_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

harness_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

harness_notice() {
  printf '%s\n' "$*" >&2
}

harness_compact_text() {
  printf '%s' "$1" \
    | tr '\r\n\t' '   ' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

harness_truncate_text() {
  local text max
  text=$(harness_compact_text "${1:-}")
  max="${2:-200}"

  if (( ${#text} <= max )); then
    printf '%s' "$text"
    return 0
  fi

  if (( max <= 3 )); then
    printf '%.*s' "$max" "$text"
    return 0
  fi

  printf '%s...' "${text:0:$((max - 3))}"
}

harness_slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

harness_project_manifest_path() {
  local root
  root=$(harness_repo_root)
  printf '%s\n' "$root/.harness/project.yaml"
}

harness_project_manifest_query() {
  local query="$1"
  local manifest
  manifest=$(harness_project_manifest_path)
  [[ -f "$manifest" ]] || return 1
  jq -er "$query" "$manifest"
}

harness_resolve_path() {
  local root="$1"
  local path="${2:-}"

  [[ -n "$path" ]] || return 1

  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  printf '%s/%s\n' "$root" "$path"
}

harness_relative_path() {
  local from="$1"
  local to="$2"

  python3 - "$from" "$to" <<'PY'
import os, sys
start = os.path.abspath(sys.argv[1])
target = os.path.abspath(sys.argv[2])
print(os.path.relpath(target, start=start))
PY
}

harness_project_topology_summary() {
  local manifest
  manifest=$(harness_project_manifest_path)
  [[ -f "$manifest" ]] || return 1

  jq -r '
    .project.topology as $topology |
    [
      "Topology:",
      "- control tower: \($topology.control_tower.transport // "unknown") / \($topology.control_tower.channel_key // "unset")",
      "- execution slots: \($topology.execution.slot_count // 0)",
      ($topology.execution.channels[]? | "- execution slot \(.slot // 0): \(.transport // "unknown") / \(.channel_key // "unset")"),
      "- runner mode: \($topology.runners.mode // "unknown")",
      ($topology.runners.entries[]? | "- runner \(.id // "unknown"): clone_root=\(.clone_root // ".") worktree_root=\(.worktree_root // ".") manager_dir=\(.manager_dir // ".harness-manager/openclaw")"),
      "- queue default label: \($topology.queue_policy.default_label // "unset")",
      "- queue claim source: \($topology.queue_policy.claim_source // "unset")"
    ] | .[]
  ' "$manifest"
}

harness_load_project_env() {
  local root config parent base
  local manifest_project_slug manifest_control_tower_key manifest_slot_count
  local manifest_queue_label manifest_runner_mode manifest_worktree_root
  local manifest_manager_dir
  root=$(harness_repo_root)
  config="$root/.harness/project.env"
  if [[ -f "$config" ]]; then
    # shellcheck source=/dev/null
    source "$config"
  fi

  manifest_project_slug=$(harness_project_manifest_query '.project.slug // empty' 2>/dev/null || true)
  manifest_control_tower_key=$(harness_project_manifest_query '.project.topology.control_tower.channel_key // empty' 2>/dev/null || true)
  manifest_slot_count=$(harness_project_manifest_query '.project.topology.execution.slot_count // empty' 2>/dev/null || true)
  manifest_queue_label=$(harness_project_manifest_query '.project.topology.queue_policy.default_label // empty' 2>/dev/null || true)
  manifest_runner_mode=$(harness_project_manifest_query '.project.topology.runners.mode // empty' 2>/dev/null || true)
  manifest_worktree_root=$(harness_project_manifest_query '.project.topology.runners.entries[0].worktree_root // empty' 2>/dev/null || true)
  manifest_manager_dir=$(harness_project_manifest_query '.project.topology.runners.entries[0].manager_dir // empty' 2>/dev/null || true)

  parent=$(dirname "$root")
  base=$(basename "$root")

  : "${HARNESS_PROJECT_MANIFEST_FILE:=$(harness_project_manifest_path)}"
  : "${HARNESS_PROJECT_SLUG:=$manifest_project_slug}"
  : "${HARNESS_REPO_SLUG:=}"
  : "${HARNESS_INTEGRATION_BRANCH:=${HARNESS_BASE_BRANCH:-main}}"
  : "${HARNESS_BASE_BRANCH:=$HARNESS_INTEGRATION_BRANCH}"
  : "${HARNESS_RELEASE_BRANCH:=main}"
  : "${HARNESS_BRANCH_PREFIX:=fix/issue-}"
  : "${HARNESS_GENERIC_BRANCH_PREFIX:=task/}"
  : "${HARNESS_AGENT_DEFAULT:=codex}"
  : "${HARNESS_LOG_DIR:=$root/.harness/logs}"
  : "${HARNESS_AUTONOMOUS_LABEL:=$manifest_queue_label}"
  : "${HARNESS_CRON_INTERVAL_MINUTES:=5}"
  : "${HARNESS_EXECUTOR_TIMEOUT_SECONDS:=240}"
  : "${HARNESS_EXECUTION_SLOT_COUNT:=${manifest_slot_count:-1}}"
  : "${HARNESS_EXECUTOR_ACTIVE_LIMIT:=$HARNESS_EXECUTION_SLOT_COUNT}"
  : "${HARNESS_REVIEW_TIMEOUT_SECONDS:=180}"
  : "${HARNESS_PREPARE_TIMEOUT_SECONDS:=300}"
  : "${HARNESS_LAND_TIMEOUT_SECONDS:=120}"
  : "${HARNESS_PREPARE_COMMANDS_FILE:=$root/.harness/prepare.commands}"
  : "${HARNESS_MERGE_METHOD:=squash}"
  : "${HARNESS_REQUIRE_GREEN_CHECKS:=0}"
  : "${HARNESS_CONTROL_ROOM_DISCORD_WEBHOOK_URL:=}"
  : "${HARNESS_CONTROL_TOWER_CHANNEL_KEY:=$manifest_control_tower_key}"
  : "${HARNESS_JIRA_BASE_URL:=}"
  : "${HARNESS_JIRA_USER_EMAIL:=}"
  : "${HARNESS_JIRA_API_TOKEN:=}"
  : "${HARNESS_LABEL_ACTIVE:=harness:in-progress}"
  : "${HARNESS_LABEL_PR_OPEN:=harness:pr-open}"
  : "${HARNESS_LABEL_DONE:=harness:done}"
  : "${HARNESS_LABEL_BLOCKED:=harness:blocked}"
  : "${HARNESS_CLAIM_TTL_MINUTES:=240}"
  : "${HARNESS_RUNNER_MODE:=${manifest_runner_mode:-single-runner}}"
  : "${HARNESS_WORKTREE_ROOT:=$(harness_resolve_path "$root" "${manifest_worktree_root:-$parent/$base-worktrees}")}"
  : "${HARNESS_TASK_DIR:=$root/.harness/tasks}"
  : "${HARNESS_STATE_DIR:=$root/.harness/state}"
  : "${HARNESS_CLAIMS_FILE:=$HARNESS_STATE_DIR/claims.json}"
  : "${HARNESS_LOCK_DIR:=$HARNESS_STATE_DIR/.lock}"
  : "${HARNESS_MANAGER_DIR:=$(harness_resolve_path "$root" "${manifest_manager_dir:-.harness-manager/openclaw}")}"
}

harness_repo_slug() {
  local root remote slug

  harness_load_project_env

  if [[ -n "$HARNESS_REPO_SLUG" ]]; then
    printf '%s\n' "$HARNESS_REPO_SLUG"
    return 0
  fi

  if command -v gh >/dev/null 2>&1; then
    slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return 0
    fi
  fi

  root=$(harness_repo_root)
  remote=$(git -C "$root" remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote" ]]; then
    return 1
  fi

  case "$remote" in
    git@github.com:*.git)
      printf '%s\n' "${remote#git@github.com:}" | sed 's/\.git$//'
      ;;
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}"
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote#https://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac
}

harness_can_sync_github() {
  command -v gh >/dev/null 2>&1 || return 1
  harness_repo_slug >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
}

harness_prepare_state() {
  harness_load_project_env
  mkdir -p "$HARNESS_TASK_DIR" "$HARNESS_STATE_DIR" "$HARNESS_LOG_DIR"
  if [[ ! -f "$HARNESS_CLAIMS_FILE" ]]; then
    printf '{}\n' > "$HARNESS_CLAIMS_FILE"
  fi
}

harness_run_with_timeout() {
  local timeout_seconds marker timer_pid command_pid status
  timeout_seconds="${1:-0}"
  shift

  if [[ "$timeout_seconds" == "0" || -z "$timeout_seconds" ]]; then
    "$@"
    return $?
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_seconds" "$@"
    return $?
  fi

  marker=$(mktemp)
  "$@" &
  command_pid=$!

  (
    sleep "$timeout_seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      printf 'timeout\n' >"$marker"
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 5
      kill -KILL "$command_pid" 2>/dev/null || true
    fi
  ) &
  timer_pid=$!

  if wait "$command_pid"; then
    status=0
  else
    status=$?
  fi

  kill "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true

  if [[ -s "$marker" ]]; then
    rm -f "$marker"
    return 124
  fi

  rm -f "$marker"
  return "$status"
}

harness_release_lock() {
  local pid_file owner_pid
  harness_load_project_env
  if [[ "${HARNESS_LOCK_HELD:-0}" != "1" ]]; then
    return 0
  fi
  pid_file="$HARNESS_LOCK_DIR/pid"
  owner_pid=$(cat "$pid_file" 2>/dev/null || true)
  if [[ -d "$HARNESS_LOCK_DIR" && ( -z "$owner_pid" || "$owner_pid" == "$$" ) ]]; then
    rm -rf "$HARNESS_LOCK_DIR"
  fi
  unset HARNESS_LOCK_HELD
}

harness_acquire_lock() {
  local started_at timeout_seconds pid_file existing_pid

  harness_load_project_env
  harness_prepare_state
  if [[ "${HARNESS_LOCK_HELD:-0}" == "1" ]]; then
    return 0
  fi
  started_at=$(date -u +%s)
  timeout_seconds=30

  while ! mkdir "$HARNESS_LOCK_DIR" 2>/dev/null; do
    pid_file="$HARNESS_LOCK_DIR/pid"
    if [[ -f "$pid_file" ]]; then
      existing_pid=$(cat "$pid_file" 2>/dev/null || true)
      if [[ -n "$existing_pid" ]] && ! kill -0 "$existing_pid" 2>/dev/null; then
        rm -rf "$HARNESS_LOCK_DIR"
        continue
      fi
    fi

    if (( $(date -u +%s) - started_at >= timeout_seconds )); then
      harness_die "timed out waiting for harness state lock"
    fi
    sleep 0.1
  done

  printf '%s\n' "$$" >"$HARNESS_LOCK_DIR/pid"
  export HARNESS_LOCK_HELD=1
}

harness_claim_key() {
  local repo task_id issue_number
  repo="${1:-}"
  issue_number="${2:-}"
  task_id="${3:-}"

  if [[ -n "$repo" && -n "$issue_number" ]]; then
    printf '%s#%s\n' "$repo" "$issue_number"
    return 0
  fi

  printf 'local:%s\n' "$task_id"
}

harness_prune_claims() {
  local cutoff epoch had_lock

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  epoch=$(date -u +%s)
  cutoff=$((epoch - HARNESS_CLAIM_TTL_MINUTES * 60))

  jq --argjson cutoff "$cutoff" '
    with_entries(
      select((.value.claimed_epoch // 0) >= $cutoff)
    )
  ' "$HARNESS_CLAIMS_FILE" >"$HARNESS_CLAIMS_FILE.tmp"
  mv "$HARNESS_CLAIMS_FILE.tmp" "$HARNESS_CLAIMS_FILE"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_claimed_issue_numbers_json() {
  local repo
  repo="$1"
  harness_prune_claims
  jq -c --arg repo "$repo" '
    [
      to_entries[]
      | select((.value.repo // "") == $repo)
      | .value.issue_number
      | select(. != null)
    ]
  ' "$HARNESS_CLAIMS_FILE"
}

harness_claim_json() {
  local key
  key="$1"
  harness_prune_claims
  jq -c --arg key "$key" '.[$key] // empty' "$HARNESS_CLAIMS_FILE"
}

harness_write_claim() {
  local key repo issue_number task_id branch worktree agent status now epoch had_lock
  key="$1"
  repo="$2"
  issue_number="$3"
  task_id="$4"
  branch="$5"
  worktree="$6"
  agent="$7"
  status="$8"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  now=$(harness_now_utc)
  epoch=$(date -u +%s)

  jq \
    --arg key "$key" \
    --arg repo "$repo" \
    --arg task_id "$task_id" \
    --arg branch "$branch" \
    --arg worktree "$worktree" \
    --arg agent "$agent" \
    --arg status "$status" \
    --arg claimed_at "$now" \
    --argjson claimed_epoch "$epoch" \
    --argjson issue_number "${issue_number:-null}" '
      .[$key] = {
        repo: $repo,
        issue_number: $issue_number,
        task_id: $task_id,
        branch: $branch,
        worktree: $worktree,
        agent: $agent,
        status: $status,
        claimed_at: $claimed_at,
        claimed_epoch: $claimed_epoch
      }
    ' "$HARNESS_CLAIMS_FILE" >"$HARNESS_CLAIMS_FILE.tmp"
  mv "$HARNESS_CLAIMS_FILE.tmp" "$HARNESS_CLAIMS_FILE"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_update_claim_status() {
  local key status note worker_log worker_exit now epoch had_lock
  key="$1"
  status="$2"
  note="${3:-}"
  worker_log="${4:-}"
  worker_exit="${5:-}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  now=$(harness_now_utc)
  epoch=$(date -u +%s)

  jq \
    --arg key "$key" \
    --arg status "$status" \
    --arg note "$note" \
    --arg worker_log "$worker_log" \
    --arg worker_exit "$worker_exit" \
    --arg updated_at "$now" \
    --argjson updated_epoch "$epoch" '
      if has($key) then
        .[$key] |= (
          .status = $status
          | .updated_at = $updated_at
          | .updated_epoch = $updated_epoch
          | if ($note | length) > 0 then .note = $note else . end
          | if ($worker_log | length) > 0 then .worker_log = $worker_log else . end
          | if ($worker_exit | length) > 0 then .worker_exit = $worker_exit else . end
        )
      else
        .
      end
    ' "$HARNESS_CLAIMS_FILE" >"$HARNESS_CLAIMS_FILE.tmp"
  mv "$HARNESS_CLAIMS_FILE.tmp" "$HARNESS_CLAIMS_FILE"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_remove_claim() {
  local key had_lock
  key="$1"
  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  jq --arg key "$key" 'del(.[$key])' "$HARNESS_CLAIMS_FILE" >"$HARNESS_CLAIMS_FILE.tmp"
  mv "$HARNESS_CLAIMS_FILE.tmp" "$HARNESS_CLAIMS_FILE"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_task_status_path() {
  local task_id
  task_id="$1"
  printf '%s/%s/task.json\n' "$HARNESS_TASK_DIR" "$task_id"
}

harness_task_dir() {
  local task_id
  task_id="$1"
  printf '%s/%s\n' "$HARNESS_TASK_DIR" "$task_id"
}

harness_task_exists() {
  local task_id
  task_id="$1"
  [[ -f "$(harness_task_status_path "$task_id")" ]]
}

harness_task_json() {
  local task_id
  task_id="$1"
  cat "$(harness_task_status_path "$task_id")"
}

harness_resolve_task_id() {
  local issue_number task_id
  issue_number="${1:-}"
  task_id="${2:-}"

  if [[ -n "$task_id" ]]; then
    printf '%s\n' "$task_id"
    return 0
  fi

  if [[ -n "$issue_number" ]]; then
    printf 'issue-%s\n' "$issue_number"
    return 0
  fi

  return 1
}

harness_task_field() {
  local task_id field
  task_id="$1"
  field="$2"
  jq -r "$field" "$(harness_task_status_path "$task_id")"
}

harness_task_review_rework_attempts() {
  local task_id
  task_id="$1"
  harness_task_field "$task_id" '.review_rework_attempts // 0'
}

harness_task_review_rework_limit() {
  local task_id
  task_id="$1"
  harness_task_field "$task_id" '.review_rework_limit // 3'
}

harness_set_task_review_state() {
  local task_id verdict rework_attempts status_file now had_lock
  task_id="$1"
  verdict="$2"
  rework_attempts="${3:-}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  status_file=$(harness_task_status_path "$task_id")
  if [[ ! -f "$status_file" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 0
  fi

  if [[ -z "$rework_attempts" ]]; then
    rework_attempts=$(jq -r '.review_rework_attempts // 0' "$status_file")
  fi

  now=$(harness_now_utc)
  jq \
    --arg verdict "$verdict" \
    --arg updated_at "$now" \
    --argjson rework_attempts "$rework_attempts" '
      .updated_at = $updated_at
      | .last_review_verdict = $verdict
      | .review_rework_attempts = $rework_attempts
    ' "$status_file" >"$status_file.tmp"
  mv "$status_file.tmp" "$status_file"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_find_next_task_by_status() {
  local status files_json
  status="$1"

  harness_load_project_env
  shopt -s nullglob
  local files=("$HARNESS_TASK_DIR"/*/task.json)
  shopt -u nullglob
  if [[ "${#files[@]}" -eq 0 ]]; then
    return 1
  fi

  files_json=$(jq -s --arg status "$status" '
    map(select(.status == $status))
    | sort_by(.updated_at // .created_at)
    | .[0] // empty
  ' "${files[@]}")

  if [[ -z "$files_json" || "$files_json" == "null" ]]; then
    return 1
  fi

  printf '%s\n' "$files_json"
}

harness_count_tasks_by_status() {
  local status
  status="$1"

  harness_load_project_env
  shopt -s nullglob
  local files=("$HARNESS_TASK_DIR"/*/task.json)
  shopt -u nullglob
  if [[ "${#files[@]}" -eq 0 ]]; then
    printf '0\n'
    return 0
  fi

  jq -s --arg status "$status" '
    map(select(.status == $status))
    | length
  ' "${files[@]}"
}

harness_artifact_dir() {
  local kind task_id
  kind="$1"
  task_id="$2"
  printf '%s/artifacts/%s/%s\n' "$(harness_repo_root)" "$kind" "$task_id"
}

harness_ensure_artifact_dir() {
  local kind task_id
  kind="$1"
  task_id="$2"
  mkdir -p "$(harness_artifact_dir "$kind" "$task_id")"
}

harness_update_task_status() {
  local task_id status_file status note pr_url now had_lock
  task_id="$1"
  status="$2"
  note="${3:-}"
  pr_url="${4:-}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  status_file=$(harness_task_status_path "$task_id")
  if [[ ! -f "$status_file" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 0
  fi

  now=$(harness_now_utc)
  jq \
    --arg status "$status" \
    --arg note "$note" \
    --arg pr_url "$pr_url" \
    --arg updated_at "$now" '
      .status = $status
      | .updated_at = $updated_at
      | if ($note | length) > 0 then .note = $note else . end
      | if ($pr_url | length) > 0 then .pr_url = $pr_url else . end
    ' "$status_file" >"$status_file.tmp"
  mv "$status_file.tmp" "$status_file"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
}

harness_transition_task_status() {
  local task_id from_status to_status note pr_url status_file current_status now had_lock
  task_id="$1"
  from_status="$2"
  to_status="$3"
  note="${4:-}"
  pr_url="${5:-}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  status_file=$(harness_task_status_path "$task_id")
  if [[ ! -f "$status_file" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 1
  fi

  current_status=$(jq -r '.status // ""' "$status_file")
  if [[ "$current_status" != "$from_status" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 1
  fi

  now=$(harness_now_utc)
  jq \
    --arg status "$to_status" \
    --arg note "$note" \
    --arg pr_url "$pr_url" \
    --arg updated_at "$now" '
      .status = $status
      | .updated_at = $updated_at
      | if ($note | length) > 0 then .note = $note else . end
      | if ($pr_url | length) > 0 then .pr_url = $pr_url else . end
    ' "$status_file" >"$status_file.tmp"
  mv "$status_file.tmp" "$status_file"

  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
  return 0
}

harness_pr_number_from_url() {
  local pr_url
  pr_url="$1"
  printf '%s\n' "${pr_url##*/}"
}

harness_fetch_pr_json() {
  local pr_ref
  pr_ref="$1"
  gh pr view "$pr_ref" --json number,title,url,state,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,statusCheckRollup,files,mergeStateStatus
}

harness_task_pr_json() {
  local task_id pr_url
  task_id="$1"
  pr_url=$(harness_task_field "$task_id" '.pr_url // ""')
  [[ -n "$pr_url" ]] || harness_die "task $task_id has no pr_url"
  harness_fetch_pr_json "$pr_url"
}

harness_issue_files_docs_only_from_pr_json() {
  local pr_json
  pr_json="$1"
  printf '%s' "$pr_json" | jq -e '
    [.files[].path]
    | length > 0
    and all(
      .[];
      (
        test("^\\.harness/")
        or test("^\\.harness-manager/")
        or test("(^|/)AGENTS\\.md$")
        or test("(^|/)CLAUDE\\.md$")
      )
      | not
      and (
        test("(^|/)(README|CHANGELOG)\\.md$")
        or test("\\.md$")
        or test("^ops/")
        or test("^\\.omx/plans/")
        or test("^artifacts/")
      )
    )
  ' >/dev/null 2>&1
}

harness_run_prepare_commands() {
  local worktree commands_file artifact_dir line idx log_file
  worktree="$1"
  artifact_dir="$2"

  harness_load_project_env
  commands_file="$HARNESS_PREPARE_COMMANDS_FILE"
  [[ -f "$commands_file" ]] || harness_die "prepare commands file not found: $commands_file"

  idx=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    idx=$((idx + 1))
    log_file="$artifact_dir/gate-$idx.log"
    if ! (cd "$worktree" && bash -lc "$line") >"$log_file" 2>&1; then
      printf '%s\n' "$line"
      return 1
    fi
  done <"$commands_file"
}

harness_extract_jira_issue_key_from_text() {
  local text line key
  text="${1:-}"
  [[ -n "$text" ]] || return 1

  line=$(printf '%s\n' "$text" | grep -im1 -E '^[[:space:]>*-]*jira([[:space:]]+issue)?[[:space:]]*:' || true)
  if [[ -n "$line" ]]; then
    key=$(printf '%s\n' "$line" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -n 1 || true)
    if [[ -n "$key" ]]; then
      printf '%s\n' "$key"
      return 0
    fi
  fi

  key=$(printf '%s\n' "$text" \
    | grep -oE 'https?://[^[:space:]]+/browse/[A-Z][A-Z0-9]+-[0-9]+' \
    | sed -E 's#.*/browse/([A-Z][A-Z0-9]+-[0-9]+)$#\1#' \
    | head -n 1 || true)
  [[ -n "$key" ]] || return 1
  printf '%s\n' "$key"
}

harness_jira_issue_url() {
  local issue_key base_url
  issue_key="${1:-}"

  harness_load_project_env
  base_url="${HARNESS_JIRA_BASE_URL%/}"
  [[ -n "$issue_key" && -n "$base_url" ]] || return 1
  printf '%s/browse/%s\n' "$base_url" "$issue_key"
}

harness_can_sync_jira() {
  harness_load_project_env
  command -v curl >/dev/null 2>&1 || return 1
  [[ -n "${HARNESS_JIRA_BASE_URL:-}" ]] || return 1
  [[ -n "${HARNESS_JIRA_USER_EMAIL:-}" ]] || return 1
  [[ -n "${HARNESS_JIRA_API_TOKEN:-}" ]] || return 1
}

harness_stage_status_id() {
  local stage event
  stage="${1:-}"
  event="${2:-}"

  case "$stage:$event" in
    claim:started) printf 'claim_started\n' ;;
    executor:started) printf 'executor_started\n' ;;
    executor:reconciled_to_pr) printf 'executor_reconciled_to_pr\n' ;;
    executor:blocked) printf 'executor_blocked\n' ;;
    review:approved) printf 'review_approved\n' ;;
    review:rework) printf 'review_rework\n' ;;
    review:rejected) printf 'review_rejected\n' ;;
    review:blocked) printf 'review_blocked\n' ;;
    prepare:passed) printf 'prepare_passed\n' ;;
    prepare:failed) printf 'prepare_failed\n' ;;
    prepare:blocked) printf 'prepare_blocked\n' ;;
    land:merged) printf 'land_merged\n' ;;
    land:failed) printf 'land_failed\n' ;;
    land:blocked) printf 'land_blocked\n' ;;
    *)
      harness_die "unsupported stage summary event: $stage/$event"
      ;;
  esac
}

harness_stage_label() {
  local stage_id
  stage_id="${1:-}"

  case "$stage_id" in
    claim_started) printf 'claim started\n' ;;
    executor_started) printf 'executor started\n' ;;
    executor_reconciled_to_pr) printf 'executor reconciled to PR\n' ;;
    executor_blocked) printf 'executor blocked\n' ;;
    review_approved) printf 'review approved\n' ;;
    review_rework) printf 'review rework\n' ;;
    review_rejected) printf 'review rejected\n' ;;
    review_blocked) printf 'review blocked\n' ;;
    prepare_passed) printf 'prepare passed\n' ;;
    prepare_failed) printf 'prepare failed\n' ;;
    prepare_blocked) printf 'prepare blocked\n' ;;
    land_merged) printf 'land merged\n' ;;
    land_failed) printf 'land failed\n' ;;
    land_blocked) printf 'land blocked\n' ;;
    *)
      harness_die "unsupported stage label: $stage_id"
      ;;
  esac
}

harness_stage_operator_action() {
  local stage_id
  stage_id="${1:-}"

  case "$stage_id" in
    executor_blocked)
      printf 'Inspect the worker outcome, then rerun or requeue the task.'
      ;;
    review_rework)
      printf ''
      ;;
    review_rejected)
      printf 'Inspect the review findings, then revise the PR or close the task.'
      ;;
    review_blocked)
      printf 'Inspect the review run, then rerun review or fix the PR.'
      ;;
    prepare_failed|prepare_blocked)
      printf 'Fix the failing verification gate or blocker, then rerun prepare.'
      ;;
    land_failed|land_blocked)
      printf 'Resolve the merge or checks blocker, then rerun land.'
      ;;
    *)
      printf ''
      ;;
  esac
}

harness_jira_comment() {
  local issue_key body payload auth_header base_url
  issue_key="$1"
  body="$2"

  harness_can_sync_jira || return 1
  [[ -n "$issue_key" ]] || return 1

  payload=$(jq -nc --arg body "$body" '{body:$body}')
  auth_header=$(printf '%s:%s' "$HARNESS_JIRA_USER_EMAIL" "$HARNESS_JIRA_API_TOKEN" | base64 | tr -d '\n')
  base_url="${HARNESS_JIRA_BASE_URL%/}"

  curl -fsS \
    -H "Authorization: Basic $auth_header" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "$base_url/rest/api/2/issue/$issue_key/comment" >/dev/null
}

harness_sync_jira_stage_summary() {
  local task_id stage_id happened pr_url blocked_reason next_action task_json jira_issue_key issue_number repo_slug issue_reference comment_body issue_body
  task_id="$1"
  stage_id="$2"
  happened="${3:-}"
  pr_url="${4:-}"
  blocked_reason="${5:-}"
  next_action="${6:-}"

  harness_can_sync_jira || return 0
  harness_task_exists "$task_id" || return 0

  task_json=$(harness_task_json "$task_id")
  jira_issue_key=$(printf '%s' "$task_json" | jq -r '.jira_issue_key // ""')
  if [[ -z "$jira_issue_key" ]]; then
    issue_body=$(printf '%s' "$task_json" | jq -r '.issue_body // ""')
    jira_issue_key=$(harness_extract_jira_issue_key_from_text "$issue_body" 2>/dev/null || true)
  fi
  [[ -n "$jira_issue_key" ]] || return 0

  issue_number=$(printf '%s' "$task_json" | jq -r '.issue_number // ""')
  repo_slug=$(printf '%s' "$task_json" | jq -r '.repo_slug // ""')
  issue_reference=$(harness_control_room_reference "$task_id" "$issue_number" "$repo_slug")

  happened=$(harness_truncate_text "$happened" 320)
  blocked_reason=$(harness_truncate_text "$blocked_reason" 220)
  next_action=$(harness_truncate_text "$next_action" 220)

  comment_body=$(
    cat <<EOF
Harness stage update

- task: \`$task_id\`
- issue: \`$issue_reference\`
- stage: \`$(harness_stage_label "$stage_id")\`
- happened: $happened
$(if [[ -n "$pr_url" ]]; then printf -- '- pr: %s\n' "$pr_url"; fi)$(if [[ -n "$blocked_reason" ]]; then printf -- '- blocked_reason: %s\n' "$blocked_reason"; fi)$(if [[ -n "$next_action" ]]; then printf -- '- operator_action: %s\n' "$next_action"; fi)
EOF
  )

  if ! harness_jira_comment "$jira_issue_key" "$comment_body"; then
    harness_notice "jira comment sync failed for $jira_issue_key ($stage_id)"
  fi
}

harness_record_stage_summary() {
  local task_id stage event happened pr_url blocked_reason next_action stage_id task_json status_file summary_json now had_lock issue_number repo_slug issue_reference jira_issue_key issue_body
  task_id="$1"
  stage="$2"
  event="$3"
  happened="${4:-}"
  pr_url="${5:-}"
  blocked_reason="${6:-}"
  next_action="${7:-}"

  harness_load_project_env
  harness_prepare_state
  harness_task_exists "$task_id" || return 0

  stage_id=$(harness_stage_status_id "$stage" "$event")
  if [[ -z "$next_action" ]]; then
    next_action=$(harness_stage_operator_action "$stage_id")
  fi

  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  status_file=$(harness_task_status_path "$task_id")
  if [[ ! -f "$status_file" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 0
  fi

  task_json=$(cat "$status_file")
  issue_number=$(printf '%s' "$task_json" | jq -r '.issue_number // ""')
  repo_slug=$(printf '%s' "$task_json" | jq -r '.repo_slug // ""')
  jira_issue_key=$(printf '%s' "$task_json" | jq -r '.jira_issue_key // ""')
  if [[ -z "$jira_issue_key" ]]; then
    issue_body=$(printf '%s' "$task_json" | jq -r '.issue_body // ""')
    jira_issue_key=$(harness_extract_jira_issue_key_from_text "$issue_body" 2>/dev/null || true)
  fi
  issue_reference=$(harness_control_room_reference "$task_id" "$issue_number" "$repo_slug")
  now=$(harness_now_utc)

  summary_json=$(jq -nc \
    --arg recorded_at "$now" \
    --arg stage "$stage" \
    --arg event "$event" \
    --arg stage_id "$stage_id" \
    --arg task_id "$task_id" \
    --arg issue_reference "$issue_reference" \
    --arg repo_slug "$repo_slug" \
    --arg jira_issue_key "$jira_issue_key" \
    --arg pr_url "$pr_url" \
    --arg happened "$happened" \
    --arg blocked_reason "$blocked_reason" \
    --arg next_action "$next_action" \
    --argjson issue_number "${issue_number:-null}" \
    '{
      recorded_at: $recorded_at,
      stage: $stage,
      event: $event,
      stage_id: $stage_id,
      task_id: $task_id,
      issue_number: $issue_number,
      repo_slug: $repo_slug,
      issue_reference: $issue_reference,
      jira_issue_key: $jira_issue_key,
      pr_url: $pr_url,
      happened: $happened,
      blocked_reason: $blocked_reason,
      next_action: $next_action
    }')

  jq \
    --arg updated_at "$now" \
    --argjson summary "$summary_json" '
      .updated_at = $updated_at
      | .last_stage_summary = $summary
      | .stage_summaries = ((.stage_summaries // []) + [$summary])
    ' "$status_file" >"$status_file.tmp"
  mv "$status_file.tmp" "$status_file"

  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi

  harness_sync_jira_stage_summary "$task_id" "$stage_id" "$happened" "$pr_url" "$blocked_reason" "$next_action"
}

harness_status_check_summary() {
  local pr_json
  pr_json="$1"
  printf '%s' "$pr_json" | jq -n --argjson pr "$pr_json" '$pr'
}

harness_pr_checks_all_green() {
  local pr_json
  pr_json="$1"
  printf '%s' "$pr_json" | jq -e '
    (.statusCheckRollup // []) as $checks
    | if ($checks | length) == 0 then false
      else all(
        $checks[];
        if .__typename == "CheckRun" then .conclusion == "SUCCESS"
        elif .__typename == "StatusContext" then .state == "SUCCESS"
        else false
        end
      )
      end
  ' >/dev/null 2>&1
}

harness_pr_checks_any_pending() {
  local pr_json
  pr_json="$1"
  printf '%s' "$pr_json" | jq -e '
    any(
      (.statusCheckRollup // [])[];
      if .__typename == "CheckRun" then (.status != "COMPLETED" or (.conclusion == null))
      elif .__typename == "StatusContext" then (.state == "PENDING" or .state == "EXPECTED")
      else false
      end
    )
  ' >/dev/null 2>&1
}

harness_pr_checks_any_failed() {
  local pr_json
  pr_json="$1"
  printf '%s' "$pr_json" | jq -e '
    any(
      (.statusCheckRollup // [])[];
      if .__typename == "CheckRun" then (.status == "COMPLETED" and .conclusion != "SUCCESS")
      elif .__typename == "StatusContext" then (.state == "ERROR" or .state == "FAILURE")
      else false
      end
    )
  ' >/dev/null 2>&1
}

harness_ensure_label() {
  local repo name color description
  repo="$1"
  name="$2"
  color="$3"
  description="$4"

  if gh label list -R "$repo" --limit 200 --json name --jq '.[].name' 2>/dev/null | grep -Fxq "$name"; then
    return 0
  fi

  gh label create "$name" -R "$repo" --color "$color" --description "$description" >/dev/null
}

harness_ensure_status_labels() {
  local repo
  repo="$1"

  harness_load_project_env
  harness_ensure_label "$repo" "$HARNESS_LABEL_ACTIVE" "0052cc" "Harness task is actively being worked"
  harness_ensure_label "$repo" "$HARNESS_LABEL_PR_OPEN" "5319e7" "Harness task has an open PR"
  harness_ensure_label "$repo" "$HARNESS_LABEL_DONE" "0e8a16" "Harness task is complete"
  harness_ensure_label "$repo" "$HARNESS_LABEL_BLOCKED" "d93f0b" "Harness task is blocked and needs intervention"
}

harness_issue_comment() {
  local repo issue_number body
  repo="$1"
  issue_number="$2"
  body="$3"
  gh issue comment "$issue_number" -R "$repo" --body "$body" >/dev/null
}

harness_control_room_reference() {
  local task_id issue_number repo_slug reference
  task_id="${1:-}"
  issue_number="${2:-}"
  repo_slug="${3:-}"

  if [[ -n "$repo_slug" && -n "$issue_number" ]]; then
    reference="$repo_slug#$issue_number"
  elif [[ -n "$issue_number" ]]; then
    reference="issue #$issue_number"
  elif [[ -n "$task_id" ]]; then
    reference="task $task_id"
  else
    reference="task"
  fi

  if [[ -n "$task_id" ]]; then
    case "$reference" in
      *"$task_id"*) ;;
      *) reference="$reference / $task_id" ;;
    esac
  fi

  printf '%s\n' "$reference"
}

harness_control_room_default_action() {
  local outcome lane task_id
  outcome="${1:-}"
  lane="${2:-}"
  task_id="${3:-}"

  case "$outcome:$lane" in
    blocked:executor)
      printf 'inspect the worker log and decide whether to resume or requeue'
      ;;
    blocked:review)
      printf 'inspect artifacts/reviews/%s and the review run log, then rerun or fix the PR' "$task_id"
      ;;
    blocked:prepare)
      printf 'inspect artifacts/prep/%s and fix the failing gate before rerunning prepare' "$task_id"
      ;;
    blocked:land)
      printf 'inspect PR checks or merge state, then rerun land when the PR is ready'
      ;;
    rejected:review)
      printf 'inspect artifacts/reviews/%s and decide whether to revise the PR or close the task' "$task_id"
      ;;
    *)
      printf ''
      ;;
  esac
}

harness_control_room_notify() {
  local outcome lane task_id issue_number repo_slug reason next_action webhook_url reference message payload
  outcome="${1:-}"
  lane="${2:-}"
  task_id="${3:-}"
  issue_number="${4:-}"
  repo_slug="${5:-}"
  reason="${6:-}"
  next_action="${7:-}"

  harness_load_project_env
  webhook_url="${HARNESS_CONTROL_ROOM_DISCORD_WEBHOOK_URL:-}"
  [[ -n "$webhook_url" ]] || return 0

  if ! command -v curl >/dev/null 2>&1; then
    harness_notice "control-room webhook skipped: curl not found"
    return 0
  fi

  reason=$(harness_truncate_text "$reason" 280)
  if [[ -z "$next_action" ]]; then
    next_action=$(harness_control_room_default_action "$outcome" "$lane" "$task_id")
  fi
  next_action=$(harness_truncate_text "$next_action" 220)
  reference=$(harness_control_room_reference "$task_id" "$issue_number" "$repo_slug")

  message="[$outcome][$lane] $reference | reason: $reason"
  if [[ -n "$next_action" ]]; then
    message="$message | next: $next_action"
  fi

  payload=$(jq -nc --arg content "$message" '{content:$content}')
  if ! curl -fsS -H "Content-Type: application/json" -X POST -d "$payload" "$webhook_url" >/dev/null; then
    harness_notice "control-room webhook post failed for $reference ($outcome/$lane)"
  fi
}

harness_issue_started() {
  local repo issue_number task_id branch worktree login
  repo="$1"
  issue_number="$2"
  task_id="$3"
  branch="$4"
  worktree="$5"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_PR_OPEN" \
    --remove-label "$HARNESS_LABEL_DONE" \
    --remove-label "$HARNESS_LABEL_BLOCKED" >/dev/null 2>&1 || true
  gh issue edit "$issue_number" -R "$repo" --add-label "$HARNESS_LABEL_ACTIVE" >/dev/null

  login=$(gh api user --jq .login 2>/dev/null || true)
  if [[ -n "$login" ]]; then
    gh issue edit "$issue_number" -R "$repo" --add-assignee "$login" >/dev/null 2>&1 || true
  fi

  harness_issue_comment "$repo" "$issue_number" \
    "Harness claim started.\n\n- task: \`$task_id\`\n- branch: \`$branch\`\n- worktree: \`$worktree\`"
}

harness_issue_pr_open() {
  local repo issue_number pr_url
  repo="$1"
  issue_number="$2"
  pr_url="$3"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_ACTIVE" \
    --remove-label "$HARNESS_LABEL_BLOCKED" \
    --add-label "$HARNESS_LABEL_PR_OPEN" >/dev/null 2>&1 || true

  harness_issue_comment "$repo" "$issue_number" \
    "Harness status update: PR opened.\n\n- pr: $pr_url"
}

harness_issue_blocked() {
  local repo issue_number reason
  repo="$1"
  issue_number="$2"
  reason="$3"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_ACTIVE" \
    --remove-label "$HARNESS_LABEL_PR_OPEN" \
    --add-label "$HARNESS_LABEL_BLOCKED" >/dev/null 2>&1 || true

  harness_issue_comment "$repo" "$issue_number" \
    "Harness status update: blocked.\n\n- reason: $reason"
}

harness_issue_rejected() {
  local repo issue_number reason
  repo="$1"
  issue_number="$2"
  reason="$3"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_ACTIVE" \
    --remove-label "$HARNESS_LABEL_BLOCKED" \
    --add-label "$HARNESS_LABEL_PR_OPEN" >/dev/null 2>&1 || true

  harness_issue_comment "$repo" "$issue_number" \
    "Harness status update: rejected.\n\n- reason: $reason"
}

harness_issue_done() {
  local repo issue_number pr_url
  repo="$1"
  issue_number="$2"
  pr_url="${3:-}"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_ACTIVE" \
    --remove-label "$HARNESS_LABEL_PR_OPEN" \
    --remove-label "$HARNESS_LABEL_BLOCKED" \
    --add-label "$HARNESS_LABEL_DONE" >/dev/null 2>&1 || true

  if [[ -n "$pr_url" ]]; then
    harness_issue_comment "$repo" "$issue_number" \
      "Harness status update: merged.\n\n- pr: $pr_url"
  else
    harness_issue_comment "$repo" "$issue_number" "Harness status update: merged."
  fi
}

harness_issue_unclaim() {
  local repo issue_number
  repo="$1"
  issue_number="$2"

  harness_load_project_env
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_ACTIVE" >/dev/null 2>&1 || true

  harness_issue_comment "$repo" "$issue_number" "Harness claim cleared."
}

harness_remote_branch_ref() {
  local base
  base="${1:-$HARNESS_BASE_BRANCH}"
  printf 'origin/%s\n' "$base"
}

harness_ensure_base_branch() {
  local root base remote_ref
  root=$(harness_repo_root)
  base="${1:-$HARNESS_BASE_BRANCH}"
  remote_ref="refs/remotes/origin/$base"

  git -C "$root" fetch origin "$base" >/dev/null
  git -C "$root" show-ref --verify --quiet "$remote_ref" \
    || harness_die "remote base branch not found after fetch: origin/$base"
}

harness_fetch_issue_json() {
  local repo issue_number
  repo="$1"
  issue_number="$2"
  gh issue view "$issue_number" -R "$repo" --json number,title,body,url,labels,assignees,state
}

harness_print_task_summary() {
  local task_id title branch worktree codex_session openclaw_session
  task_id="$1"
  title="$2"
  branch="$3"
  worktree="$4"
  codex_session="$5"
  openclaw_session="$6"

  printf 'task_id=%s\n' "$task_id"
  printf 'title=%s\n' "$title"
  printf 'branch=%s\n' "$branch"
  printf 'worktree=%s\n' "$worktree"
  printf 'codex_session=%s\n' "$codex_session"
  printf 'openclaw_session=%s\n' "$openclaw_session"
}
