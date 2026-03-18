#!/usr/bin/env python3
import argparse
import os
from datetime import datetime, timezone
from pathlib import Path

from structured_io import dump_structured, load_structured


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def acquire_lock(lock_path: Path):
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise RuntimeError(f"{lock_path}: single-promoter lock already held") from exc
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(utc_now() + "\n")


def release_lock(lock_path: Path):
    try:
        lock_path.unlink()
    except FileNotFoundError:
        pass


def discover_cycle_dirs(root: Path):
    cycle_dirs = []
    for cycle_json in sorted(root.glob("*/cycle.json")):
        cycle_dirs.append(cycle_json.parent)
    return cycle_dirs


def load_cycle_bundle(cycle_dir: Path):
    cycle = load_structured(cycle_dir / "cycle.json", default={}) or {}
    decision = load_structured(cycle_dir / "outputs" / "decision.json", default={}) or {}
    changed_files = cycle.get("changed_files", [])
    files_changed_path = cycle_dir / "artifacts" / "files_changed.txt"
    if files_changed_path.exists():
        changed_files = files_changed_path.read_text(encoding="utf-8").splitlines() or changed_files

    before_score = cycle.get("before_score")
    after_score = cycle.get("after_score")
    try:
        score_delta = float(after_score) - float(before_score)
    except (TypeError, ValueError):
        score_delta = None

    proposed_decision = decision.get("decision") or cycle.get("proposed_decision") or cycle.get("status")
    conflict_keys = list(cycle.get("conflict_keys", []))
    for changed_file in changed_files:
        key = f"file:{changed_file}"
        if key not in conflict_keys:
            conflict_keys.append(key)

    return {
        "cycle_id": cycle.get("cycle_id", cycle_dir.name),
        "cycle_dir": str(cycle_dir),
        "target": cycle.get("target"),
        "status": cycle.get("status"),
        "decision": proposed_decision,
        "selected_gap": cycle.get("selected_gap"),
        "before_score": before_score,
        "after_score": after_score,
        "score_delta": score_delta,
        "seed_regression_pass": cycle.get("seed_regression_pass"),
        "conflict_keys": conflict_keys,
        "changed_files": changed_files,
    }


def pick_promotions(cycles):
    promotable = [cycle for cycle in cycles if cycle["decision"] == "promote"]
    promotable.sort(key=lambda item: (item["score_delta"] is None, -(item["score_delta"] or 0), item["cycle_id"]))

    winners = []
    skipped = []
    used_keys = set()

    for cycle in promotable:
        conflicts = sorted(set(cycle["conflict_keys"]) & used_keys)
        if conflicts:
            skipped.append({**cycle, "blocked_by_conflict_keys": conflicts})
            continue
        winners.append(cycle)
        used_keys.update(cycle["conflict_keys"])

    return winners, skipped, sorted(used_keys)


def render_markdown(summary):
    lines = [
        "# Fan-in summary",
        "",
        "## Overview",
        f"- generated at: `{summary['generated_at']}`",
        f"- discovered cycles: `{summary['summary']['discovered_cycles']}`",
        f"- promote candidates: `{summary['summary']['promote_candidates']}`",
        f"- winners: `{summary['summary']['winner_count']}`",
        "",
        "## Winners",
    ]
    if summary["winners"]:
        for winner in summary["winners"]:
            lines.append(
                f"- `{winner['cycle_id']}` / decision `{winner['decision']}` / score delta `{winner['score_delta']}`"
            )
    else:
        lines.append("- none")

    lines.extend(["", "## Blocked promote candidates"])
    if summary["blocked_promotes"]:
        for blocked in summary["blocked_promotes"]:
            lines.append(
                f"- `{blocked['cycle_id']}` blocked by `{', '.join(blocked['blocked_by_conflict_keys'])}`"
            )
    else:
        lines.append("- none")

    lines.extend(["", "## Deferred or rollback cycles"])
    deferred_like = [cycle for cycle in summary["cycles"] if cycle["decision"] in {"defer", "rollback"}]
    if deferred_like:
        for cycle in deferred_like:
            lines.append(f"- `{cycle['cycle_id']}` / decision `{cycle['decision']}`")
    else:
        lines.append("- none")

    lines.extend(
        [
            "",
            "## Integrated rerun requirements",
            "- re-run target eval after merging the winner set",
            "- re-run seed regression after merging the winner set",
            "- keep only if merged result still satisfies promote criteria",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def update_scoreboard(scoreboard_path: Path, summary):
    scoreboard = load_structured(scoreboard_path, default={}) or {}
    history = scoreboard.get("history", [])
    if not isinstance(history, list):
        history = []
    history.append(
        {
            "generated_at": summary["generated_at"],
            "winner_count": summary["summary"]["winner_count"],
            "promote_candidates": summary["summary"]["promote_candidates"],
            "discovered_cycles": summary["summary"]["discovered_cycles"],
        }
    )
    scoreboard = {
        "updated_at": summary["generated_at"],
        "history": history,
        "totals": {
            "batches": len(history),
            "winner_count": sum(item["winner_count"] for item in history),
            "promote_candidates": sum(item["promote_candidates"] for item in history),
        },
    }
    dump_structured(scoreboard_path, scoreboard)


def main():
    parser = argparse.ArgumentParser(description="Fan in parallel ontlab cycle results under a single-promoter lock.")
    parser.add_argument("cycle_dirs", nargs="*", help="Optional explicit cycle directories")
    parser.add_argument("--root", default="cycle_runs", help="Cycle run root for discovery and output")
    parser.add_argument("--output-json", default="cycle_runs/fan_in_summary.json", help="JSON summary output")
    parser.add_argument("--output-md", default="cycle_runs/fan_in_summary.md", help="Markdown summary output")
    parser.add_argument("--scoreboard", default="cycle_runs/scoreboard.json", help="Scoreboard output")
    args = parser.parse_args()

    root = Path(args.root)
    lock_path = root / "locks" / "promoter.lock"
    acquire_lock(lock_path)
    try:
        cycle_dirs = [Path(path) for path in args.cycle_dirs] if args.cycle_dirs else discover_cycle_dirs(root)
        cycles = [load_cycle_bundle(cycle_dir) for cycle_dir in cycle_dirs]
        winners, blocked_promotes, used_keys = pick_promotions(cycles)
        summary = {
            "generated_at": utc_now(),
            "root": str(root.resolve()),
            "cycles": cycles,
            "winners": winners,
            "blocked_promotes": blocked_promotes,
            "used_conflict_keys": used_keys,
            "summary": {
                "discovered_cycles": len(cycles),
                "promote_candidates": len([cycle for cycle in cycles if cycle["decision"] == "promote"]),
                "winner_count": len(winners),
                "defer_count": len([cycle for cycle in cycles if cycle["decision"] == "defer"]),
                "rollback_count": len([cycle for cycle in cycles if cycle["decision"] == "rollback"]),
            },
        }
        dump_structured(Path(args.output_json), summary)
        Path(args.output_md).write_text(render_markdown(summary), encoding="utf-8")
        update_scoreboard(Path(args.scoreboard), summary)
        print(args.output_json)
    finally:
        release_lock(lock_path)


if __name__ == "__main__":
    main()
