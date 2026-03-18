#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

def slugify(path: str) -> str:
    return path.strip("/").replace("/", "_").replace(" ", "_")

def main():
    parser = argparse.ArgumentParser(description="Bootstrap a target repository instance workspace.")
    parser.add_argument("repo_name", help="Human-readable or path-like repo name")
    parser.add_argument("--root", default="instances", help="Instance root directory")
    args = parser.parse_args()

    slug = slugify(args.repo_name)
    root = Path(args.root) / slug
    for sub in ["graph", "evidence", "questions", "answers", "eval", "reports"]:
        (root / sub).mkdir(parents=True, exist_ok=True)

    meta = {
        "repo_name": args.repo_name,
        "slug": slug,
        "status": "bootstrapped",
        "notes": [
            "Populate graph/ with generated ontology instance artifacts.",
            "Store question sets under questions/ and evaluation outputs under eval/."
        ],
    }
    (root / "instance.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(root)

if __name__ == "__main__":
    main()
