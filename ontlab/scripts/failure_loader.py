import json
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - depends on local environment
    yaml = None


def _normalize_failures(data, source: Path):
    if data is None:
        return []
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        failures = data.get("failures", [])
        if isinstance(failures, list):
            return failures
        raise ValueError(f"{source}: 'failures' must be a list")
    raise ValueError(f"{source}: unsupported failure payload type {type(data).__name__}")


def _load_jsonl(text: str):
    failures = []
    for line in text.splitlines():
        line = line.strip()
        if line:
            failures.append(json.loads(line))
    return failures


def _load_json(text: str):
    return json.loads(text)


def _load_yaml(text: str, source: Path):
    if yaml is None:
        raise RuntimeError(f"{source}: PyYAML is required to read YAML failure files")
    return yaml.safe_load(text)


def load_failures(path: Path):
    if not path.exists():
        return []

    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()
    if suffix == ".jsonl":
        return _load_jsonl(text)

    parsers = [_load_json, lambda value: _load_yaml(value, path)]
    if suffix in {".yaml", ".yml"}:
        parsers.reverse()

    errors = []
    for parser in parsers:
        try:
            return _normalize_failures(parser(text), path)
        except Exception as exc:
            errors.append(f"{parser.__name__}: {exc}")

    joined = "; ".join(errors)
    raise ValueError(f"{path}: could not parse failure file ({joined})")
