#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from structured_io import dump_structured, load_structured, parse_assignments


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def append_jsonl(path: Path, item):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(item, ensure_ascii=False) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Append a step-level event to an ontlab cycle run.")
    parser.add_argument("cycle_dir", help="Path to cycle_runs/<cycle_id>")
    parser.add_argument("--phase", required=True, help="Cycle phase name")
    parser.add_argument("--message", required=True, help="Human-readable event message")
    parser.add_argument("--actor", default="codex", help="Actor name")
    parser.add_argument("--status", help="Optional cycle status update")
    parser.add_argument("--decision", help="Optional decision update: pending/promote/defer/rollback")
    parser.add_argument("--metric", action="append", default=[], help="Metric update in KEY=VALUE form")
    parser.add_argument("--field", action="append", default=[], help="Top-level cycle.json field update in KEY=VALUE form")
    parser.add_argument("--changed-file", action="append", default=[], help="Changed file to append to cycle.json")
    parser.add_argument("--command", action="append", default=[], help="Executed command to append to trace/commands.jsonl")
    args = parser.parse_args()

    cycle_dir = Path(args.cycle_dir)
    cycle_path = cycle_dir / "cycle.json"
    cycle = load_structured(cycle_path, default={})
    if not isinstance(cycle, dict):
        raise ValueError(f"{cycle_path}: expected a JSON object")

    metrics = parse_assignments(args.metric)
    fields = parse_assignments(args.field)
    now = utc_now()

    event = {
        "ts": now,
        "phase": args.phase,
        "actor": args.actor,
        "message": args.message,
        "status": args.status,
        "decision": args.decision,
        "metrics": metrics,
        "fields": fields,
        "changed_files": args.changed_file,
        "commands": args.command,
    }
    append_jsonl(cycle_dir / "trace" / "events.jsonl", event)

    for command in args.command:
        append_jsonl(
            cycle_dir / "trace" / "commands.jsonl",
            {
                "ts": now,
                "actor": args.actor,
                "phase": args.phase,
                "command": command,
            },
        )

    cycle["current_phase"] = args.phase
    cycle["updated_at"] = now
    cycle["last_event_at"] = now
    if args.status:
        cycle["status"] = args.status
    if args.decision:
        cycle["proposed_decision"] = args.decision
        dump_structured(
            cycle_dir / "outputs" / "decision.json",
            {
                "decision": args.decision,
                "reason": args.message,
                "generated_at": now,
            },
        )

    cycle_metrics = cycle.get("metrics", {})
    if not isinstance(cycle_metrics, dict):
        cycle_metrics = {}
    cycle_metrics.update(metrics)
    cycle["metrics"] = cycle_metrics

    for key, value in fields.items():
        cycle[key] = value

    changed_files = list(cycle.get("changed_files", []))
    for changed_file in args.changed_file:
        if changed_file not in changed_files:
            changed_files.append(changed_file)
    cycle["changed_files"] = changed_files

    dump_structured(cycle_path, cycle)
    if args.changed_file:
        files_changed_path = cycle_dir / "artifacts" / "files_changed.txt"
        existing = files_changed_path.read_text(encoding="utf-8").splitlines() if files_changed_path.exists() else []
        merged = existing[:]
        for changed_file in args.changed_file:
            if changed_file not in merged:
                merged.append(changed_file)
        files_changed_path.write_text("\n".join(merged) + ("\n" if merged else ""), encoding="utf-8")

    print(cycle_dir / "trace" / "events.jsonl")


if __name__ == "__main__":
    main()
