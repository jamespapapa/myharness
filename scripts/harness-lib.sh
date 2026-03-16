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

harness_control_room_idle_line() {
  printf 'checked: no work (Ready queue empty)\n'
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
  : "${HARNESS_LABEL_ACTIVE:=harness:in-progress}"
  : "${HARNESS_LABEL_PR_OPEN:=harness:pr-open}"
  : "${HARNESS_LABEL_DONE:=harness:done}"
  : "${HARNESS_LABEL_BLOCKED:=harness:blocked}"
  : "${HARNESS_LABEL_DEV_BATCH:=harness:in-dev-batch}"
  : "${HARNESS_LABEL_RELEASED:=harness:released}"
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
  if [[ ! -f "$(harness_release_batches_path)" ]]; then
    cat >"$(harness_release_batches_path)" <<EOF
{
  "schema_version": 1,
  "integration_branch": "$HARNESS_INTEGRATION_BRANCH",
  "release_branch": "$HARNESS_RELEASE_BRANCH",
  "active_batch_id": null,
  "batches": []
}
EOF
  fi
}

harness_release_batches_path() {
  printf '%s/release-batches.json\n' "$HARNESS_STATE_DIR"
}

harness_release_batch_id() {
  local integration release stamp
  harness_load_project_env
  integration=$(harness_slugify "$HARNESS_INTEGRATION_BRANCH")
  release=$(harness_slugify "$HARNESS_RELEASE_BRANCH")
  stamp=$(date -u +"%Y%m%dT%H%M%SZ")
  printf '%s-to-%s-%s-%s\n' "$integration" "$release" "$stamp" "$RANDOM"
}

harness_active_changelog_relpath() {
  printf 'CHANGELOG.md\n'
}

harness_release_changelog_relpath() {
  local batch_id
  batch_id="${1:?}"
  printf 'artifacts/releases/%s.md\n' "$batch_id"
}

harness_active_changelog_path() {
  printf '%s/%s\n' "$(harness_repo_root)" "$(harness_active_changelog_relpath)"
}

harness_release_changelog_path() {
  local batch_id
  batch_id="${1:?}"
  printf '%s/%s\n' "$(harness_repo_root)" "$(harness_release_changelog_relpath "$batch_id")"
}

harness_active_changelog_batch_id() {
  local changelog_file
  changelog_file="${1:-$(harness_active_changelog_path)}"
  [[ -f "$changelog_file" ]] || return 0
  sed -n 's/^<!-- batch:\(.*\) -->$/\1/p' "$changelog_file" | head -n 1
}

harness_write_active_changelog_header() {
  local batch_id started_at changelog_file
  batch_id="$1"
  started_at="$2"
  changelog_file=$(harness_active_changelog_path)
  cat >"$changelog_file" <<EOF
# CHANGELOG

<!-- batch:$batch_id -->
Active integration batch: $HARNESS_INTEGRATION_BRANCH -> $HARNESS_RELEASE_BRANCH
Started: $started_at

EOF
}

harness_reset_active_changelog() {
  local changelog_file
  changelog_file=$(harness_active_changelog_path)
  cat >"$changelog_file" <<EOF
# CHANGELOG

Active integration batch: $HARNESS_INTEGRATION_BRANCH -> $HARNESS_RELEASE_BRANCH
No unreleased entries yet.

EOF
}

harness_ensure_active_changelog() {
  local batch_id started_at changelog_file current_batch
  batch_id="$1"
  started_at="${2:-$(harness_now_utc)}"
  changelog_file=$(harness_active_changelog_path)
  current_batch=$(harness_active_changelog_batch_id "$changelog_file" || true)
  if [[ ! -f "$changelog_file" || "$current_batch" != "$batch_id" ]]; then
    harness_write_active_changelog_header "$batch_id" "$started_at"
  fi
}

harness_append_issue_to_active_changelog() {
  local task_id issue_number pr_number pr_url merge_sha merged_at batch_id
  local title changelog_file entry_marker merged_day
  task_id="$1"
  issue_number="$2"
  pr_number="$3"
  pr_url="$4"
  merge_sha="$5"
  merged_at="$6"
  batch_id="$7"

  title=$(harness_task_field "$task_id" '.title // ""' 2>/dev/null || true)
  [[ -n "$title" ]] || title="Issue $issue_number"
  harness_ensure_active_changelog "$batch_id" "$merged_at"
  changelog_file=$(harness_active_changelog_path)
  entry_marker="<!-- issue:$issue_number -->"
  if grep -Fq "$entry_marker" "$changelog_file" 2>/dev/null; then
    return 0
  fi

  merged_day="${merged_at%%T*}"
  {
    printf '%s\n' "$entry_marker"
    printf -- '- %s · issue #%s · %s (PR #%s)\n' "$merged_day" "$issue_number" "$title" "$pr_number"
  } >>"$changelog_file"
}

harness_archive_active_changelog() {
  local batch_id released_at pr_number pr_url merge_sha
  local active_file archive_file archive_relpath release_dir current_batch
  batch_id="$1"
  released_at="$2"
  pr_number="$3"
  pr_url="$4"
  merge_sha="$5"

  active_file=$(harness_active_changelog_path)
  archive_relpath=$(harness_release_changelog_relpath "$batch_id")
  archive_file=$(harness_release_changelog_path "$batch_id")
  release_dir=$(dirname "$archive_file")
  current_batch=$(harness_active_changelog_batch_id "$active_file" || true)
  mkdir -p "$release_dir"

  if [[ ! -f "$archive_file" ]]; then
    cat >"$archive_file" <<EOF
# Release Changelog

- batch: $batch_id
- integration: $HARNESS_INTEGRATION_BRANCH -> $HARNESS_RELEASE_BRANCH
- released_at: $released_at
- release_pr: $pr_url
- release_pr_number: #$pr_number
- release_merge_sha: $merge_sha

EOF
    if [[ -f "$active_file" && "$current_batch" == "$batch_id" ]]; then
      cat "$active_file" >>"$archive_file"
    else
      printf '%s\n' '_No active CHANGELOG.md content was available for this batch._' >>"$archive_file"
    fi
  fi

  harness_reset_active_changelog
  printf '%s\n' "$archive_relpath"
}

harness_record_issue_in_active_release_batch() {
  local task_id issue_number pr_number pr_url merge_sha merged_at release_file active_batch_id active_changelog_path
  local status_file had_lock
  task_id="$1"
  issue_number="$2"
  pr_number="$3"
  pr_url="$4"
  merge_sha="$5"
  merged_at="${6:-$(harness_now_utc)}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  release_file=$(harness_release_batches_path)
  active_batch_id=$(jq -r '.active_batch_id // ""' "$release_file")
  active_changelog_path=$(harness_active_changelog_relpath)

  if [[ -z "$active_batch_id" || "$active_batch_id" == "null" ]]; then
    active_batch_id=$(harness_release_batch_id)
    jq \
      --arg batch_id "$active_batch_id" \
      --arg integration_branch "$HARNESS_INTEGRATION_BRANCH" \
      --arg release_branch "$HARNESS_RELEASE_BRANCH" \
      --arg active_changelog_path "$active_changelog_path" \
      --arg created_at "$merged_at" '
        .integration_branch = $integration_branch
        | .release_branch = $release_branch
        | .active_batch_id = $batch_id
        | .batches += [{
            id: $batch_id,
            integration_branch: $integration_branch,
            release_branch: $release_branch,
            status: "active",
            created_at: $created_at,
            window_start: $created_at,
            window_end: $created_at,
            active_changelog_path: $active_changelog_path,
            released_at: null,
            release_pr_number: null,
            release_pr_url: null,
            release_merge_sha: null,
            release_changelog_path: null,
            issues: []
          }]
      ' "$release_file" >"$release_file.tmp"
    mv "$release_file.tmp" "$release_file"
  fi

  jq \
    --arg batch_id "$active_batch_id" \
    --arg integration_branch "$HARNESS_INTEGRATION_BRANCH" \
    --arg release_branch "$HARNESS_RELEASE_BRANCH" \
    --arg active_changelog_path "$active_changelog_path" \
    --arg task_id "$task_id" \
    --arg pr_url "$pr_url" \
    --arg merge_sha "$merge_sha" \
    --arg merged_at "$merged_at" \
    --argjson issue_number "$issue_number" \
    --argjson pr_number "$pr_number" '
      .integration_branch = $integration_branch
      | .release_branch = $release_branch
      | .active_batch_id = $batch_id
      | .batches = (
          .batches
          | map(
              if .id == $batch_id then
                .integration_branch = $integration_branch
                | .release_branch = $release_branch
                | .status = "active"
                | .active_changelog_path = $active_changelog_path
                | .window_start = (
                    if ((.window_start // "") | length) == 0 or $merged_at < .window_start
                    then $merged_at
                    else .window_start
                    end
                  )
                | .window_end = (
                    if ((.window_end // "") | length) == 0 or $merged_at > .window_end
                    then $merged_at
                    else .window_end
                    end
                  )
                | .issues = (
                    (.issues // []) as $issues
                    | if any($issues[]?; (.issue_number // null) == $issue_number) then
                        $issues
                        | map(
                            if (.issue_number // null) == $issue_number then
                              .task_id = $task_id
                              | .pr_number = $pr_number
                              | .pr_url = $pr_url
                              | .merge_sha = $merge_sha
                              | .merged_at = $merged_at
                              | .integration_changelog_path = $active_changelog_path
                              | .released_at = null
                              | .release_pr_number = null
                              | .release_pr_url = null
                              | .release_merge_sha = null
                              | .release_changelog_path = null
                            else .
                            end
                          )
                      else
                        $issues + [{
                          issue_number: $issue_number,
                          task_id: $task_id,
                          pr_number: $pr_number,
                          pr_url: $pr_url,
                          merge_sha: $merge_sha,
                          merged_at: $merged_at,
                          integration_changelog_path: $active_changelog_path,
                          released_at: null,
                          release_pr_number: null,
                          release_pr_url: null,
                          release_merge_sha: null,
                          release_changelog_path: null
                        }]
                      end
                  )
              else .
              end
            )
        )
    ' "$release_file" >"$release_file.tmp"
  mv "$release_file.tmp" "$release_file"

  status_file=$(harness_task_status_path "$task_id")
  if [[ -f "$status_file" ]]; then
    jq \
      --arg batch_id "$active_batch_id" \
      --arg merged_at "$merged_at" \
      --arg merge_sha "$merge_sha" \
      --arg integration_changelog_path "$active_changelog_path" '
        .release_batch_id = $batch_id
        | .merged_to_integration_at = $merged_at
        | .integration_merge_sha = $merge_sha
        | .integration_changelog_path = $integration_changelog_path
        | del(.released_to_main_at, .release_pr_url, .release_pr_number, .release_merge_sha, .release_changelog_path)
      ' "$status_file" >"$status_file.tmp"
    mv "$status_file.tmp" "$status_file"
  fi

  harness_append_issue_to_active_changelog "$task_id" "$issue_number" "$pr_number" "$pr_url" "$merge_sha" "$merged_at" "$active_batch_id"

  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi

  printf '%s\n' "$active_batch_id"
}

harness_promote_active_release_batch() {
  local task_id pr_number pr_url merge_sha released_at repo_slug
  local release_file active_batch_id issue_numbers status_file had_lock release_changelog_path
  task_id="$1"
  pr_number="$2"
  pr_url="$3"
  merge_sha="$4"
  released_at="${5:-$(harness_now_utc)}"
  repo_slug="${6:-}"

  harness_load_project_env
  harness_prepare_state
  had_lock="${HARNESS_LOCK_HELD:-0}"
  harness_acquire_lock
  release_file=$(harness_release_batches_path)
  active_batch_id=$(jq -r '.active_batch_id // ""' "$release_file")

  if [[ -z "$active_batch_id" || "$active_batch_id" == "null" ]]; then
    if [[ "$had_lock" != "1" ]]; then
      harness_release_lock
    fi
    return 0
  fi

  issue_numbers=$(jq -r --arg batch_id "$active_batch_id" '
    .batches[]
    | select(.id == $batch_id)
    | .issues[]?.issue_number
  ' "$release_file")
  release_changelog_path=$(harness_archive_active_changelog "$active_batch_id" "$released_at" "$pr_number" "$pr_url" "$merge_sha")

  jq \
    --arg batch_id "$active_batch_id" \
    --arg integration_branch "$HARNESS_INTEGRATION_BRANCH" \
    --arg release_branch "$HARNESS_RELEASE_BRANCH" \
    --arg release_changelog_path "$release_changelog_path" \
    --arg released_at "$released_at" \
    --arg pr_url "$pr_url" \
    --arg merge_sha "$merge_sha" \
    --argjson pr_number "$pr_number" '
      .integration_branch = $integration_branch
      | .release_branch = $release_branch
      | .active_batch_id = null
      | .batches = (
          .batches
          | map(
              if .id == $batch_id then
                .integration_branch = $integration_branch
                | .release_branch = $release_branch
                | .status = "released"
                | .released_at = $released_at
                | .release_pr_number = $pr_number
                | .release_pr_url = $pr_url
                | .release_merge_sha = $merge_sha
                | .release_changelog_path = $release_changelog_path
                | .issues = [
                    (.issues // [])[]
                    | .released_at = $released_at
                    | .release_pr_number = $pr_number
                    | .release_pr_url = $pr_url
                    | .release_merge_sha = $merge_sha
                    | .release_changelog_path = $release_changelog_path
                  ]
              else .
              end
            )
        )
    ' "$release_file" >"$release_file.tmp"
  mv "$release_file.tmp" "$release_file"

  status_file=$(harness_task_status_path "$task_id")
  if [[ -f "$status_file" ]]; then
    jq \
      --arg released_at "$released_at" \
      --arg pr_url "$pr_url" \
      --arg merge_sha "$merge_sha" \
      --arg batch_id "$active_batch_id" \
      --arg release_changelog_path "$release_changelog_path" \
      --argjson pr_number "$pr_number" '
        .release_batch_id = $batch_id
        | .released_to_main_at = $released_at
        | .release_pr_url = $pr_url
        | .release_pr_number = $pr_number
        | .release_merge_sha = $merge_sha
        | .release_changelog_path = $release_changelog_path
      ' "$status_file" >"$status_file.tmp"
    mv "$status_file.tmp" "$status_file"
  fi

  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi

  if [[ -z "$repo_slug" ]]; then
    repo_slug=$(harness_repo_slug 2>/dev/null || true)
  fi
  if [[ -n "$repo_slug" ]] && harness_can_sync_github; then
    while IFS= read -r issue_number; do
      [[ -n "$issue_number" ]] || continue
      harness_issue_released_to_main "$repo_slug" "$issue_number" "$active_batch_id" "$released_at" "$pr_url" "$merge_sha"
    done <<<"$issue_numbers"
  fi

  printf '%s\n' "$active_batch_id"
}

harness_record_release_metadata_for_pr() {
  local task_id issue_number repo_slug pr_number pr_url base_ref head_ref merge_sha merged_at batch_id
  task_id="$1"
  issue_number="${2:-}"
  repo_slug="${3:-}"
  pr_number="$4"
  pr_url="$5"
  base_ref="$6"
  head_ref="${7:-}"
  merge_sha="${8:-}"
  merged_at="${9:-$(harness_now_utc)}"

  harness_load_project_env

  if [[ "$base_ref" == "$HARNESS_INTEGRATION_BRANCH" ]]; then
    [[ -n "$issue_number" ]] || return 0
    batch_id=$(harness_record_issue_in_active_release_batch "$task_id" "$issue_number" "$pr_number" "$pr_url" "$merge_sha" "$merged_at")
    if [[ -z "$repo_slug" ]]; then
      repo_slug=$(harness_repo_slug 2>/dev/null || true)
    fi
    if [[ -n "$repo_slug" ]] && harness_can_sync_github; then
      harness_issue_added_to_dev_batch "$repo_slug" "$issue_number" "$batch_id" "$merged_at" "$pr_url" "$merge_sha"
    fi
    return 0
  fi

  if [[ "$base_ref" == "$HARNESS_RELEASE_BRANCH" && "$head_ref" == "$HARNESS_INTEGRATION_BRANCH" ]]; then
    harness_promote_active_release_batch "$task_id" "$pr_number" "$pr_url" "$merge_sha" "$merged_at" "$repo_slug" >/dev/null
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
      select(
        ((.value.status // "") == "assigned")
        or ((.value.claimed_epoch // 0) >= $cutoff)
      )
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

harness_resolve_assignment_slot() {
  local slot="${1:-}"

  harness_load_project_env
  if [[ -z "$slot" ]]; then
    slot="${HARNESS_DEFAULT_ASSIGNMENT_SLOT:-default}"
  fi
  printf '%s\n' "$slot"
}

harness_resolve_assignment_channel() {
  local channel="${1:-}"

  harness_load_project_env
  if [[ -z "$channel" ]]; then
    channel="${HARNESS_DEFAULT_ASSIGNMENT_CHANNEL:-control-room}"
  fi
  printf '%s\n' "$channel"
}

harness_write_claim() {
  local key repo issue_number task_id branch worktree agent status assignment_slot assignment_channel assigned_by now epoch had_lock
  key="$1"
  repo="$2"
  issue_number="$3"
  task_id="$4"
  branch="$5"
  worktree="$6"
  agent="$7"
  status="$8"
  assignment_slot=$(harness_resolve_assignment_slot "${9:-}")
  assignment_channel=$(harness_resolve_assignment_channel "${10:-}")
  assigned_by="${11:-$agent}"

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
    --arg assignment_slot "$assignment_slot" \
    --arg assignment_channel "$assignment_channel" \
    --arg assigned_by "$assigned_by" \
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
        claimed_epoch: $claimed_epoch,
        assignment: {
          slot: $assignment_slot,
          channel: $assignment_channel,
          assigned_by: $assigned_by,
          assigned_at: $claimed_at
        }
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

harness_set_task_assignment() {
  local task_id assignment_slot assignment_channel assigned_by status_file now had_lock
  task_id="$1"
  assignment_slot=$(harness_resolve_assignment_slot "${2:-}")
  assignment_channel=$(harness_resolve_assignment_channel "${3:-}")
  assigned_by="${4:-task-start}"

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
    --arg assignment_slot "$assignment_slot" \
    --arg assignment_channel "$assignment_channel" \
    --arg assigned_by "$assigned_by" \
    --arg assigned_at "$now" \
    --arg updated_at "$now" '
      .updated_at = $updated_at
      | .assignment = {
          slot: $assignment_slot,
          channel: $assignment_channel,
          assigned_by: $assigned_by,
          assigned_at: $assigned_at
        }
    ' "$status_file" >"$status_file.tmp"
  mv "$status_file.tmp" "$status_file"
  if [[ "$had_lock" != "1" ]]; then
    harness_release_lock
  fi
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
  gh pr view "$pr_ref" --json number,title,url,state,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,mergedAt,statusCheckRollup,files,mergeStateStatus
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
    review:stale) printf 'review_stale\n' ;;
    prepare:passed) printf 'prepare_passed\n' ;;
    prepare:failed) printf 'prepare_failed\n' ;;
    prepare:blocked) printf 'prepare_blocked\n' ;;
    prepare:stale) printf 'prepare_stale\n' ;;
    land:merged) printf 'land_merged\n' ;;
    land:failed) printf 'land_failed\n' ;;
    land:blocked) printf 'land_blocked\n' ;;
    land:deferred) printf 'land_deferred\n' ;;
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
    review_stale) printf 'review stale\n' ;;
    prepare_passed) printf 'prepare passed\n' ;;
    prepare_failed) printf 'prepare failed\n' ;;
    prepare_blocked) printf 'prepare blocked\n' ;;
    prepare_stale) printf 'prepare stale\n' ;;
    land_merged) printf 'land merged\n' ;;
    land_failed) printf 'land failed\n' ;;
    land_blocked) printf 'land blocked\n' ;;
    land_deferred) printf 'land deferred\n' ;;
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
      printf 'Executor should repair the same PR branch, rerun verification, and hand back the updated head.'
      ;;
    review_rejected)
      printf 'Inspect the review findings, then revise the PR or close the task.'
      ;;
    review_blocked)
      printf 'Inspect the review run, then rerun review or fix the PR.'
      ;;
    review_stale)
      printf 'Rerun review on the latest PR head after the branch settles.'
      ;;
    prepare_failed|prepare_blocked)
      printf 'Fix the failing verification gate or blocker, then rerun prepare.'
      ;;
    prepare_stale)
      printf 'Rerun review and prepare on the latest PR head before landing.'
      ;;
    land_failed|land_blocked)
      printf 'Resolve the merge or checks blocker, then rerun land.'
      ;;
    land_deferred)
      printf 'Refresh review and prepare artifacts on the current PR head, then rerun land.'
      ;;
    *)
      printf ''
      ;;
  esac
}

harness_issue_stage_comment() {
  local repo issue_number stage_label happened pr_url blocked_reason next_action comment_body
  repo="$1"
  issue_number="$2"
  stage_label="$3"
  happened="${4:-}"
  pr_url="${5:-}"
  blocked_reason="${6:-}"
  next_action="${7:-}"

  harness_can_sync_github || return 0
  [[ -n "$repo" && -n "$issue_number" ]] || return 0

  happened=$(harness_truncate_text "$happened" 320)
  blocked_reason=$(harness_truncate_text "$blocked_reason" 220)
  next_action=$(harness_truncate_text "$next_action" 220)

  comment_body=$(
    cat <<EOF
Harness stage update: $stage_label.

- result: $happened
$(if [[ -n "$pr_url" ]]; then printf -- '- pr: %s\n' "$pr_url"; fi)$(if [[ -n "$blocked_reason" ]]; then printf -- '- reason: %s\n' "$blocked_reason"; fi)$(if [[ -n "$next_action" ]]; then printf -- '- next: %s\n' "$next_action"; fi)
EOF
  )

  harness_issue_comment "$repo" "$issue_number" "$comment_body"
}

harness_sync_github_stage_summary() {
  local task_id stage_id happened pr_url blocked_reason next_action task_json issue_number repo_slug
  task_id="$1"
  stage_id="$2"
  happened="${3:-}"
  pr_url="${4:-}"
  blocked_reason="${5:-}"
  next_action="${6:-}"

  harness_task_exists "$task_id" || return 0

  task_json=$(harness_task_json "$task_id")
  issue_number=$(printf '%s' "$task_json" | jq -r '.issue_number // ""')
  repo_slug=$(printf '%s' "$task_json" | jq -r '.repo_slug // ""')
  harness_issue_stage_comment "$repo_slug" "$issue_number" "$(harness_stage_label "$stage_id")" "$happened" "$pr_url" "$blocked_reason" "$next_action" \
    || harness_notice "github issue comment sync failed for $task_id ($stage_id)"
}

harness_record_stage_summary() {
  local task_id stage event happened pr_url blocked_reason next_action stage_id task_json status_file summary_json now had_lock issue_number repo_slug issue_reference
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

  harness_sync_github_stage_summary "$task_id" "$stage_id" "$happened" "$pr_url" "$blocked_reason" "$next_action"
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
  harness_ensure_label "$repo" "$HARNESS_LABEL_DEV_BATCH" "1d76db" "Harness issue is part of the active dev release batch"
  harness_ensure_label "$repo" "$HARNESS_LABEL_RELEASED" "0a8f3d" "Harness issue was promoted from dev to main"
}

harness_issue_added_to_dev_batch() {
  local repo issue_number batch_id merged_at pr_url merge_sha payload
  repo="$1"
  issue_number="$2"
  batch_id="$3"
  merged_at="$4"
  pr_url="${5:-}"
  merge_sha="${6:-}"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_RELEASED" \
    --add-label "$HARNESS_LABEL_DEV_BATCH" >/dev/null 2>&1 || true

  payload=$(jq -nc \
    --arg event "dev_batch_joined" \
    --arg batch_id "$batch_id" \
    --arg integration_branch "$HARNESS_INTEGRATION_BRANCH" \
    --arg release_branch "$HARNESS_RELEASE_BRANCH" \
    --arg merged_at "$merged_at" \
    --arg pr_url "$pr_url" \
    --arg merge_sha "$merge_sha" '
      {
        event: $event,
        batch_id: $batch_id,
        integration_branch: $integration_branch,
        release_branch: $release_branch,
        merged_at: $merged_at,
        pr_url: (if ($pr_url | length) > 0 then $pr_url else null end),
        merge_sha: (if ($merge_sha | length) > 0 then $merge_sha else null end)
      }
    ')

  harness_issue_comment "$repo" "$issue_number" \
"Harness release tracking: added to the active dev batch.

\`\`\`json
$payload
\`\`\`"
}

harness_issue_released_to_main() {
  local repo issue_number batch_id released_at pr_url merge_sha payload
  repo="$1"
  issue_number="$2"
  batch_id="$3"
  released_at="$4"
  pr_url="${5:-}"
  merge_sha="${6:-}"

  harness_load_project_env
  harness_ensure_status_labels "$repo"
  gh issue edit "$issue_number" -R "$repo" \
    --remove-label "$HARNESS_LABEL_DEV_BATCH" \
    --add-label "$HARNESS_LABEL_DONE" \
    --add-label "$HARNESS_LABEL_RELEASED" >/dev/null 2>&1 || true

  payload=$(jq -nc \
    --arg event "released_to_main" \
    --arg batch_id "$batch_id" \
    --arg integration_branch "$HARNESS_INTEGRATION_BRANCH" \
    --arg release_branch "$HARNESS_RELEASE_BRANCH" \
    --arg released_at "$released_at" \
    --arg pr_url "$pr_url" \
    --arg merge_sha "$merge_sha" '
      {
        event: $event,
        batch_id: $batch_id,
        integration_branch: $integration_branch,
        release_branch: $release_branch,
        released_at: $released_at,
        release_pr_url: (if ($pr_url | length) > 0 then $pr_url else null end),
        release_merge_sha: (if ($merge_sha | length) > 0 then $merge_sha else null end)
      }
    ')

  harness_issue_comment "$repo" "$issue_number" \
"Harness release tracking: promoted from dev to main.

\`\`\`json
$payload
\`\`\`"
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

harness_task_base_sync_reason() {
  local task_id task_json worktree branch base_branch base_remote_ref remote_base_sha
  task_id="$1"

  harness_task_exists "$task_id" || return 1
  task_json=$(harness_task_json "$task_id")
  worktree=$(printf '%s' "$task_json" | jq -r '.worktree // ""')
  branch=$(printf '%s' "$task_json" | jq -r '.branch // ""')
  base_branch=$(printf '%s' "$task_json" | jq -r '.base_branch // ""')
  base_remote_ref=$(printf '%s' "$task_json" | jq -r '.base_remote_ref // ""')

  [[ -n "$worktree" && -n "$base_branch" ]] || return 1
  if [[ -z "$base_remote_ref" ]]; then
    base_remote_ref=$(harness_remote_branch_ref "$base_branch")
  fi

  harness_ensure_base_branch "$base_branch"
  remote_base_sha=$(git -C "$worktree" rev-parse "$base_remote_ref" 2>/dev/null || true)
  [[ -n "$remote_base_sha" ]] || return 1

  if git -C "$worktree" merge-base --is-ancestor "$remote_base_sha" HEAD >/dev/null 2>&1; then
    return 0
  fi

  printf 'base branch sync required: %s is missing latest %s (%s); merge %s into %s, rerun verification, and only then hand off the task.\n' \
    "$branch" "$base_remote_ref" "$remote_base_sha" "$base_remote_ref" "$branch"
  return 1
}

harness_fetch_issue_json() {
  local repo issue_number
  repo="$1"
  issue_number="$2"
  gh issue view "$issue_number" -R "$repo" --json number,title,body,url,labels,assignees,state
}

harness_print_task_summary() {
  local task_id title branch worktree codex_session openclaw_session assignment_slot assignment_channel
  task_id="$1"
  title="$2"
  branch="$3"
  worktree="$4"
  codex_session="$5"
  openclaw_session="$6"
  assignment_slot="$7"
  assignment_channel="$8"

  printf 'task_id=%s\n' "$task_id"
  printf 'title=%s\n' "$title"
  printf 'branch=%s\n' "$branch"
  printf 'worktree=%s\n' "$worktree"
  printf 'codex_session=%s\n' "$codex_session"
  printf 'openclaw_session=%s\n' "$openclaw_session"
  printf 'assignment_slot=%s\n' "$assignment_slot"
  printf 'assignment_channel=%s\n' "$assignment_channel"
}
