#!/usr/bin/env python3
import argparse
from datetime import datetime, timezone
from pathlib import Path

from structured_io import dump_structured, load_structured


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def slugify(value: str) -> str:
    cleaned = []
    for char in value.lower():
        cleaned.append(char if char.isalnum() else "-")
    joined = "".join(cleaned)
    while "--" in joined:
        joined = joined.replace("--", "-")
    return joined.strip("-") or "candidate"


def normalize_candidates(data):
    if data is None:
        return []
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ["candidates", "gaps", "items", "failures"]:
            value = data.get(key)
            if isinstance(value, list):
                return value
        return [data]
    raise ValueError("Candidate payload must be a list or object")


def normalize_candidate(raw, index):
    candidate_id = str(raw.get("gap_id") or raw.get("id") or raw.get("slug") or f"candidate-{index}")
    selected_gap = str(raw.get("selected_gap") or raw.get("title") or raw.get("question") or candidate_id)
    score = raw.get("priority")
    if score is None:
        score = raw.get("score")
    if score is None:
        score = raw.get("weight", 0)
    try:
        numeric_score = float(score)
    except (TypeError, ValueError):
        numeric_score = 0.0

    conflict_keys = []
    for key in raw.get("conflict_keys", []):
        conflict_keys.append(str(key))
    for pack in raw.get("pack_candidates", []):
        conflict_keys.append(f"pack:{pack}")
    for path in raw.get("files_likely_to_change", []):
        conflict_keys.append(f"file:{path}")
    for asset in raw.get("shared_assets", []):
        conflict_keys.append(f"asset:{asset}")
    for rule in raw.get("rule_scope", []):
        conflict_keys.append(f"rule:{rule}")
    for changed_file in raw.get("changed_files", []):
        conflict_keys.append(f"file:{changed_file}")

    unique_conflicts = []
    for key in conflict_keys:
        if key not in unique_conflicts:
            unique_conflicts.append(key)

    return {
        "gap_id": candidate_id,
        "selected_gap": selected_gap,
        "target": raw.get("target"),
        "score": numeric_score,
        "pack_candidates": raw.get("pack_candidates", []),
        "files_likely_to_change": raw.get("files_likely_to_change", []),
        "shared_assets": raw.get("shared_assets", []),
        "conflict_keys": unique_conflicts,
        "source": raw,
        "cycle_id_suggestion": f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%SZ')}__{slugify(candidate_id)}",
    }


def select_batch(candidates, max_parallel):
    ordered = sorted(
        candidates,
        key=lambda item: (-item["score"], item["gap_id"]),
    )
    selected = []
    deferred = []
    used_keys = set()

    for candidate in ordered:
        conflicts = sorted(set(candidate["conflict_keys"]) & used_keys)
        if len(selected) >= max_parallel or conflicts:
            deferred.append({
                **candidate,
                "blocked_by_conflict_keys": conflicts,
                "reason": "conflict" if conflicts else "capacity",
            })
            continue

        selected.append(candidate)
        used_keys.update(candidate["conflict_keys"])

    return selected, deferred, sorted(used_keys)


def main():
    parser = argparse.ArgumentParser(description="Select a conflict-free fan-out batch for ontlab cycles.")
    parser.add_argument("candidate_file", help="Structured file with candidate gaps")
    parser.add_argument("--max-parallel", type=int, default=4, help="Maximum concurrent cycles")
    parser.add_argument(
        "-o",
        "--output",
        default="cycle_runs/batch-plan.json",
        help="Output file for the selected batch",
    )
    parser.add_argument("--batch-id", help="Optional batch id")
    args = parser.parse_args()

    payload = load_structured(Path(args.candidate_file), default=[])
    raw_candidates = normalize_candidates(payload)
    candidates = [normalize_candidate(item, index) for index, item in enumerate(raw_candidates, start=1)]
    selected, deferred, used_keys = select_batch(candidates, args.max_parallel)

    batch_plan = {
        "batch_id": args.batch_id or datetime.now(timezone.utc).strftime("batch-%Y%m%d-%H%M%S"),
        "generated_at": utc_now(),
        "candidate_file": args.candidate_file,
        "max_parallel": args.max_parallel,
        "selected_count": len(selected),
        "deferred_count": len(deferred),
        "used_conflict_keys": used_keys,
        "selected": selected,
        "deferred": deferred,
    }
    dump_structured(Path(args.output), batch_plan)
    print(args.output)


if __name__ == "__main__":
    main()
