#!/usr/bin/env python3
import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from structured_io import dump_structured, load_structured


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run_git(repo_root: Path, args):
    return subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )


def branch_exists(repo_root: Path, branch: str) -> bool:
    try:
        run_git(repo_root, ["show-ref", "--verify", f"refs/heads/{branch}"])
        return True
    except subprocess.CalledProcessError:
        return False


def append_jsonl(path: Path, item):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(item, ensure_ascii=False) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Materialize a cycle's isolated git worktree from cycle.json.")
    parser.add_argument("cycle_dir", help="Path to cycle_runs/<cycle_id>")
    parser.add_argument("--repo-root", help="Git repository root; defaults to git rev-parse --show-toplevel")
    parser.add_argument("--base-ref", default="HEAD", help="Base ref for a new worktree branch")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually run git worktree add; otherwise only update cycle.json with the planned command",
    )
    args = parser.parse_args()

    cycle_dir = Path(args.cycle_dir)
    cycle_path = cycle_dir / "cycle.json"
    cycle = load_structured(cycle_path, default={}) or {}
    if not isinstance(cycle, dict):
        raise ValueError(f"{cycle_path}: expected a JSON object")

    repo_root = Path(args.repo_root) if args.repo_root else Path(
        run_git(Path.cwd(), ["rev-parse", "--show-toplevel"]).stdout.strip()
    )
    worktree_path = Path(cycle["worktree"])
    branch = cycle["branch"]
    now = utc_now()

    if branch_exists(repo_root, branch):
        command = ["git", "worktree", "add", str(worktree_path), branch]
        branch_mode = "reuse-existing-branch"
    else:
        command = ["git", "worktree", "add", "-b", branch, str(worktree_path), args.base_ref]
        branch_mode = "create-branch"

    cycle["worktree_repo_root"] = str(repo_root)
    cycle["worktree_base_ref"] = args.base_ref
    cycle["worktree_command"] = command
    cycle["worktree_branch_mode"] = branch_mode
    cycle["worktree_status"] = "planned"
    cycle["updated_at"] = now

    if args.execute:
        worktree_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(command, cwd=repo_root, check=True)
        cycle["worktree_status"] = "created"
        cycle["updated_at"] = utc_now()
        append_jsonl(
            cycle_dir / "trace" / "commands.jsonl",
            {
                "ts": cycle["updated_at"],
                "actor": "create_cycle_worktree.py",
                "phase": "worktree",
                "command": " ".join(command),
            },
        )

    append_jsonl(
        cycle_dir / "trace" / "events.jsonl",
        {
            "ts": cycle["updated_at"],
            "phase": "worktree",
            "actor": "create_cycle_worktree.py",
            "message": "Planned isolated worktree command" if not args.execute else "Created isolated worktree",
            "status": cycle.get("status"),
            "decision": cycle.get("proposed_decision"),
            "metrics": {},
            "fields": {
                "worktree_status": cycle["worktree_status"],
                "worktree_base_ref": cycle["worktree_base_ref"],
            },
            "changed_files": [],
            "commands": [" ".join(command)],
        },
    )
    dump_structured(cycle_path, cycle)
    print(" ".join(command))


if __name__ == "__main__":
    main()
