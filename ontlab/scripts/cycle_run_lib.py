import json
import re
from datetime import datetime, timezone
from pathlib import Path

CYCLE_SUBDIRECTORIES = ("input", "trace", "artifacts", "outputs")


def now_utc():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def timestamp_prefix():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def slugify(value: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    return cleaned or "cycle"


def make_cycle_id(summary: str) -> str:
    return f"{timestamp_prefix()}__{slugify(summary)[:48]}"


def ensure_cycle_dir(root: Path, cycle_id: str) -> Path:
    cycle_dir = root / cycle_id
    cycle_dir.mkdir(parents=True, exist_ok=True)
    for name in CYCLE_SUBDIRECTORIES:
        (cycle_dir / name).mkdir(exist_ok=True)
    return cycle_dir


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def append_jsonl(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def unique_extend(values, additions):
    seen = set(values)
    for item in additions:
        if item and item not in seen:
            values.append(item)
            seen.add(item)
    return values


def load_gap_candidates(path: Path):
    payload = read_json(path)
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        gaps = payload.get("gaps", [])
        if isinstance(gaps, list):
            return gaps
    raise ValueError(f"{path}: expected a JSON list or an object with a 'gaps' list")


def gap_conflict_keys(gap):
    keys = set()
    for path in gap.get("likely_files", []):
        keys.add(f"file:{path}")
    for pack in gap.get("pack_candidates", []):
        keys.add(f"pack:{pack}")
    for resource in gap.get("shared_resources", []):
        keys.add(f"resource:{resource}")
    for skill in gap.get("touches_skills", []):
        keys.add(f"skill:{skill}")
    return keys


def cycle_conflict_keys(cycle):
    keys = set(cycle.get("conflict_keys", []))
    for path in cycle.get("changed_files", []):
        keys.add(f"file:{path}")
    for resource in cycle.get("shared_resources", []):
        keys.add(f"resource:{resource}")
    for skill in cycle.get("touches_skills", []):
        keys.add(f"skill:{skill}")
    for pack in cycle.get("pack_candidates", []):
        keys.add(f"pack:{pack}")
    return keys


def score_delta(cycle):
    before = cycle.get("before_score")
    after = cycle.get("after_score")
    if isinstance(before, (int, float)) and isinstance(after, (int, float)):
        return after - before
    return None
