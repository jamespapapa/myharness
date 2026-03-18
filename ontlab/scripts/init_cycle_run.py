#!/usr/bin/env python3
import argparse
import re
from datetime import datetime, timezone
from pathlib import Path

from structured_io import dump_structured, load_structured


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-+", "-", value).strip("-")
    return value or "cycle"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def default_cycle_id(selected_gap: str) -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    return f"{timestamp}__{slugify(selected_gap)}"


def infer_conflict_keys(candidate, extra_keys):
    keys = set(extra_keys)
    if isinstance(candidate, dict):
        explicit = candidate.get("conflict_keys", [])
        if isinstance(explicit, list):
            keys.update(str(item) for item in explicit)

        for pack in candidate.get("pack_candidates", []):
            keys.add(f"pack:{pack}")
        for path in candidate.get("files_likely_to_change", []):
            keys.add(f"file:{path}")
        for asset in candidate.get("shared_assets", []):
            keys.add(f"asset:{asset}")
        for rule in candidate.get("rule_scope", []):
            keys.add(f"rule:{rule}")
    return sorted(keys)


def load_candidate(path: str):
    if not path:
        return None
    data = load_structured(Path(path))
    if isinstance(data, list):
        if len(data) != 1:
            raise ValueError("Candidate file must contain exactly one item when using list input")
        return data[0]
    return data


def default_prompt_text(selected_gap: str) -> str:
    return (
        "Isolated ontlab cycle.\n"
        f"Selected gap: {selected_gap}\n"
        "Apply one smallest safe change, record every step in cycle_runs/<cycle_id>/trace/events.jsonl, "
        "and leave a decision in outputs/decision.json.\n"
    )


def main():
    parser = argparse.ArgumentParser(description="Initialize a file-backed ontlab cycle run scaffold.")
    parser.add_argument("--target", required=True, help="Target instance path, e.g. instances/my-target-repo")
    parser.add_argument("--selected-gap", required=True, help="Human-readable gap description")
    parser.add_argument("--cycle-id", help="Explicit cycle id; otherwise generated from UTC timestamp and gap")
    parser.add_argument("--parent-cycle", help="Optional parent cycle id")
    parser.add_argument("--root", default="cycle_runs", help="Cycle run root directory")
    parser.add_argument("--worktree-root", default=".worktrees", help="Directory used to suggest isolated worktree paths")
    parser.add_argument("--branch-prefix", default="cycle", help="Git branch prefix for cycle branches")
    parser.add_argument("--candidate-file", help="Structured file containing the selected gap payload")
    parser.add_argument("--prompt-file", help="Optional prompt text to copy into input/prompt.txt")
    parser.add_argument("--touch", action="append", default=[], help="Conflict key to reserve for this cycle")
    args = parser.parse_args()

    candidate = load_candidate(args.candidate_file)
    selected_gap = args.selected_gap
    cycle_id = args.cycle_id or default_cycle_id(selected_gap)
    now = utc_now()

    root = Path(args.root)
    cycle_dir = root / cycle_id
    target_path = Path(args.target)
    worktree_path = (Path(args.worktree_root) / cycle_id).resolve()
    instance_tmp = (target_path / "tmp" / cycle_id).resolve()
    branch = f"{args.branch_prefix}/{slugify(cycle_id)}"

    for subdir in [
        cycle_dir / "input",
        cycle_dir / "trace",
        cycle_dir / "artifacts",
        cycle_dir / "outputs",
    ]:
        subdir.mkdir(parents=True, exist_ok=True)

    prompt_text = (
        Path(args.prompt_file).read_text(encoding="utf-8")
        if args.prompt_file
        else default_prompt_text(selected_gap)
    )
    conflict_keys = infer_conflict_keys(candidate, args.touch)
    selected_gap_payload = candidate if candidate is not None else {
        "selected_gap": selected_gap,
        "conflict_keys": conflict_keys,
    }

    cycle_json = {
        "cycle_id": cycle_id,
        "target": args.target,
        "status": "planned",
        "current_phase": "initialized",
        "selected_gap": selected_gap,
        "before_score": None,
        "after_score": None,
        "seed_regression_pass": None,
        "worktree": str(worktree_path),
        "branch": branch,
        "parent_cycle": args.parent_cycle,
        "instance_tmp": str(instance_tmp),
        "seed_corpus_mode": "read-only",
        "conflict_keys": conflict_keys,
        "changed_files": [],
        "metrics": {},
        "proposed_decision": "pending",
        "created_at": now,
        "updated_at": now,
    }

    (cycle_dir / "input" / "target_repo.txt").write_text(args.target + "\n", encoding="utf-8")
    dump_structured(cycle_dir / "input" / "selected_gap.json", selected_gap_payload)
    (cycle_dir / "input" / "prompt.txt").write_text(prompt_text, encoding="utf-8")

    for trace_file in [
        cycle_dir / "trace" / "commands.jsonl",
        cycle_dir / "trace" / "codex_trace.jsonl",
        cycle_dir / "trace" / "approvals.jsonl",
        cycle_dir / "trace" / "events.jsonl",
    ]:
        trace_file.write_text("", encoding="utf-8")

    for artifact_file in [
        cycle_dir / "artifacts" / "files_changed.txt",
        cycle_dir / "artifacts" / "patch.diff",
    ]:
        artifact_file.write_text("", encoding="utf-8")

    for structured_artifact in [
        cycle_dir / "artifacts" / "before_eval.json",
        cycle_dir / "artifacts" / "after_eval.json",
        cycle_dir / "artifacts" / "seed_regression.json",
    ]:
        dump_structured(structured_artifact, {})

    dump_structured(
        cycle_dir / "outputs" / "decision.json",
        {
            "decision": "pending",
            "reason": "Initialized but not executed yet.",
            "generated_at": now,
        },
    )
    (cycle_dir / "outputs" / "report.md").write_text(
        "# Cycle report\n\nInitialized. Fill this after execution.\n",
        encoding="utf-8",
    )
    (cycle_dir / "outputs" / "next_cycle_brief.md").write_text(
        "# Next cycle brief\n\nPending cycle completion.\n",
        encoding="utf-8",
    )
    dump_structured(cycle_dir / "cycle.json", cycle_json)
    print(cycle_dir)


if __name__ == "__main__":
    main()
