#!/usr/bin/env python3
import argparse
import collections
from pathlib import Path

from failure_loader import load_failures

def main():
    parser = argparse.ArgumentParser(description="Summarize answer failures by bucket and candidate pack.")
    parser.add_argument("failure_file")
    args = parser.parse_args()

    failures = load_failures(Path(args.failure_file))
    by_bucket = collections.Counter()
    by_pack = collections.Counter()
    for item in failures:
        by_bucket[item.get("bucket","unknown")] += 1
        for pack in item.get("pack_candidates", []):
            by_pack[pack] += 1

    print("Top buckets:")
    for k,v in by_bucket.most_common():
        print(f"{k:30} {v}")
    print("\nTop pack candidates:")
    for k,v in by_pack.most_common():
        print(f"{k:30} {v}")

if __name__ == "__main__":
    main()
