#!/usr/bin/env python3
import argparse
import collections
from pathlib import Path

from failure_loader import load_failures

def choose_one(failures):
    if not failures:
        return None
    bucket_counts = collections.Counter(item.get("bucket","unknown") for item in failures)
    pack_counts = collections.Counter()
    for item in failures:
        for pack in item.get("pack_candidates", []):
            pack_counts[pack] += 1
    top_bucket = bucket_counts.most_common(1)[0][0]
    top_pack = pack_counts.most_common(1)[0][0] if pack_counts else "unknown-pack"
    return top_bucket, top_pack

def main():
    parser = argparse.ArgumentParser(description="Create a next-cycle brief from eval failures.")
    parser.add_argument("failure_file")
    parser.add_argument("-o", "--output", default="reports/next-cycle-brief.md")
    args = parser.parse_args()

    failures = load_failures(Path(args.failure_file))
    choice = choose_one(failures)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    if not choice:
        content = "# Next cycle brief\n\nNo failures found.\n"
    else:
        top_bucket, top_pack = choice
        content = f'''# Next cycle brief

## Proposed focus
- failure bucket: {top_bucket}
- likely pack: {top_pack}

## Why
This was the highest-signal recurring failure class in the current eval file.

## Rules
- choose the smallest safe change
- do not change core ontology first
- add or update eval coverage
- write a cycle report
'''
    out.write_text(content, encoding="utf-8")
    print(out)

if __name__ == "__main__":
    main()
