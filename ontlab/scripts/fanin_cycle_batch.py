#!/usr/bin/env python3
import argparse
from pathlib import Path

from cycle_run_lib import cycle_conflict_keys, now_utc, read_json, score_delta, timestamp_prefix, write_json


def resolve_cycle_files(inputs):
    files = []
    for raw in inputs:
        path = Path(raw)
        if path.is_file():
            files.append(path)
            continue
        cycle_json = path / "cycle.json"
        if cycle_json.exists():
            files.append(cycle_json)
            continue
        files.extend(sorted(path.glob("*/cycle.json")))
    return files


def decision_for(cycle_path: Path, cycle):
    decision_path = cycle_path.parent / "outputs" / "decision.json"
    if decision_path.exists():
        payload = read_json(decision_path)
        if payload.get("decision"):
            return payload["decision"]
    status = cycle.get("status")
    if status in {"promote", "defer", "rollback"}:
        return status
    return "pending"


def candidate_summary(cycle_path: Path, cycle, decision: str):
    return {
        "cycle_id": cycle.get("cycle_id"),
        "cycle_path": str(cycle_path),
        "decision": decision,
        "before_score": cycle.get("before_score"),
        "after_score": cycle.get("after_score"),
        "score_delta": score_delta(cycle),
        "seed_regression_pass": cycle.get("seed_regression_pass"),
        "changed_files": cycle.get("changed_files", []),
        "conflict_keys": sorted(cycle_conflict_keys(cycle)),
    }


def default_output_path(root: Path) -> Path:
    return root / "fanin" / f"{timestamp_prefix()}.json"


def sort_promote_candidates(item):
    delta = item.get("score_delta")
    return (-(delta if isinstance(delta, (int, float)) else -999999), item["cycle_id"])


def main():
    parser = argparse.ArgumentParser(description="Aggregate cycle results for single-promoter fan-in.")
    parser.add_argument("inputs", nargs="+", help="cycle.json paths or directories containing cycle runs")
    parser.add_argument("--root", default="cycle_runs", help="Cycle run root directory")
    parser.add_argument("-o", "--output", help="Output fan-in summary path")
    args = parser.parse_args()

    cycle_files = resolve_cycle_files(args.inputs)
    promote_candidates = []
    deferred = []
    rollback = []

    for cycle_path in cycle_files:
        cycle = read_json(cycle_path)
        decision = decision_for(cycle_path, cycle)
        item = candidate_summary(cycle_path, cycle, decision)
        if decision == "promote":
            promote_candidates.append(item)
        elif decision == "rollback":
            rollback.append(item)
        else:
            deferred.append(item)

    winners = []
    conflicted_promotes = []
    reserved_keys = set()
    for item in sorted(promote_candidates, key=sort_promote_candidates):
        item_keys = set(item["conflict_keys"])
        overlapping = sorted(item_keys & reserved_keys)
        if overlapping:
            conflicted_promotes.append(
                {
                    **item,
                    "conflicts_with_reserved_keys": overlapping,
                }
            )
            continue
        winners.append(item)
        reserved_keys.update(item_keys)

    output_path = Path(args.output) if args.output else default_output_path(Path(args.root))
    write_json(
        output_path,
        {
            "created_at": now_utc(),
            "single_promoter": True,
            "requires_integrated_rerun": bool(winners),
            "winner_count": len(winners),
            "winners": winners,
            "conflicted_promotes": conflicted_promotes,
            "deferred": deferred,
            "rollback": rollback,
            "reserved_keys": sorted(reserved_keys),
        },
    )
    print(output_path)


if __name__ == "__main__":
    main()
