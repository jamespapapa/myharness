#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from cycle_run_lib import append_jsonl, now_utc, read_json, unique_extend, write_json


def parse_bool(value: str) -> bool:
    lowered = value.strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise argparse.ArgumentTypeError(f"invalid boolean value: {value}")


def parse_metric(raw: str):
    if "=" not in raw:
        raise argparse.ArgumentTypeError("metric must be key=value")
    key, value = raw.split("=", 1)
    key = key.strip()
    value = value.strip()
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        parsed = value
    return key, parsed


def main():
    parser = argparse.ArgumentParser(description="Update cycle.json and append a stage event.")
    parser.add_argument("cycle_dir", help="Path to cycle run directory")
    parser.add_argument("--stage", help="Current stage name")
    parser.add_argument("--status", help="Current cycle status")
    parser.add_argument("--decision", choices=["promote", "defer", "rollback"], help="Promotion decision")
    parser.add_argument("--before-score", type=float)
    parser.add_argument("--after-score", type=float)
    parser.add_argument("--seed-regression-pass", type=parse_bool)
    parser.add_argument("--selected-gap")
    parser.add_argument("--note")
    parser.add_argument("--changed-file", action="append", default=[])
    parser.add_argument("--likely-file", action="append", default=[])
    parser.add_argument("--shared-resource", action="append", default=[])
    parser.add_argument("--pack-candidate", action="append", default=[])
    parser.add_argument("--touches-skill", action="append", default=[])
    parser.add_argument("--conflict-key", action="append", default=[])
    parser.add_argument("--metric", action="append", default=[], type=parse_metric)
    args = parser.parse_args()

    cycle_dir = Path(args.cycle_dir)
    cycle_path = cycle_dir / "cycle.json"
    cycle = read_json(cycle_path)
    timestamp = now_utc()

    if args.stage:
        cycle["current_phase"] = args.stage
    if args.status:
        cycle["status"] = args.status
    if args.selected_gap:
        cycle["selected_gap"] = args.selected_gap
    if args.before_score is not None:
        cycle["before_score"] = args.before_score
    if args.after_score is not None:
        cycle["after_score"] = args.after_score
    if args.seed_regression_pass is not None:
        cycle["seed_regression_pass"] = args.seed_regression_pass

    unique_extend(cycle.setdefault("changed_files", []), args.changed_file)
    unique_extend(cycle.setdefault("likely_files", []), args.likely_file)
    unique_extend(cycle.setdefault("shared_resources", []), args.shared_resource)
    unique_extend(cycle.setdefault("pack_candidates", []), args.pack_candidate)
    unique_extend(cycle.setdefault("touches_skills", []), args.touches_skill)
    unique_extend(cycle.setdefault("conflict_keys", []), args.conflict_key)

    metrics = cycle.setdefault("metrics", {})
    for key, value in args.metric:
        metrics[key] = value

    if args.note:
        cycle.setdefault("notes", []).append(args.note)

    cycle["updated_at"] = timestamp
    write_json(cycle_path, cycle)

    if args.decision:
        write_json(
            cycle_dir / "outputs" / "decision.json",
            {
                "decision": args.decision,
                "updated_at": timestamp,
                "status": cycle.get("status"),
                "reason": args.note or "",
                "before_score": cycle.get("before_score"),
                "after_score": cycle.get("after_score"),
                "seed_regression_pass": cycle.get("seed_regression_pass"),
            },
        )

    append_jsonl(
        cycle_dir / "trace" / "events.jsonl",
        {
            "timestamp": timestamp,
            "phase": cycle.get("current_phase"),
            "status": cycle.get("status"),
            "decision": args.decision,
            "note": args.note,
            "metrics": metrics,
        },
    )
    print(cycle_path)


if __name__ == "__main__":
    main()
