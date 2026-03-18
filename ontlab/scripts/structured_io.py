#!/usr/bin/env python3
import json
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - depends on local environment
    yaml = None


def _require_yaml(path: Path):
    if yaml is None:
        raise RuntimeError(f"{path}: PyYAML is required for YAML input/output")


def load_structured(path: Path, default=None):
    if not path.exists():
        return default

    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()

    if suffix == ".jsonl":
        return [json.loads(line) for line in text.splitlines() if line.strip()]
    if suffix == ".json":
        return json.loads(text) if text.strip() else default
    if suffix in {".yaml", ".yml"}:
        _require_yaml(path)
        data = yaml.safe_load(text)
        return default if data is None else data

    raise ValueError(f"{path}: unsupported structured file suffix '{suffix}'")


def dump_structured(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    suffix = path.suffix.lower()

    if suffix == ".jsonl":
        if not isinstance(data, list):
            raise ValueError(f"{path}: jsonl output expects a list of items")
        text = "\n".join(json.dumps(item, ensure_ascii=False) for item in data)
        if text:
            text += "\n"
        path.write_text(text, encoding="utf-8")
        return

    if suffix == ".json":
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return

    if suffix in {".yaml", ".yml"}:
        _require_yaml(path)
        path.write_text(
            yaml.safe_dump(data, allow_unicode=True, sort_keys=False),
            encoding="utf-8",
        )
        return

    raise ValueError(f"{path}: unsupported structured file suffix '{suffix}'")


def coerce_scalar(value: str):
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered in {"null", "none"}:
        return None

    try:
        return int(value)
    except ValueError:
        pass

    try:
        return float(value)
    except ValueError:
        pass

    if value[:1] in {"[", "{"}:
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value
    return value


def parse_assignments(pairs):
    values = {}
    for raw in pairs:
        if "=" not in raw:
            raise ValueError(f"Assignment must be KEY=VALUE: '{raw}'")
        key, value = raw.split("=", 1)
        values[key] = coerce_scalar(value)
    return values
