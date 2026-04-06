#!/usr/bin/env python3
import sys
from pathlib import Path

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) < 1:
        print("Usage: validate_workflow.py <path_to_workflow.yml>", file=sys.stderr)
        return 1

    f = argv[0]

    if not HAS_YAML:
        print(f"FAIL {f}: PyYAML is required (e.g. install via 'uv pip install PyYAML').", file=sys.stderr)
        return 1

    try:
        path = Path(f)
        if not path.is_file():
            print(f"FAIL {f}: File not found or is not a file", file=sys.stderr)
            return 1

        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise TypeError("workflow root must be a mapping")
        print(f"OK   {f}")
        return 0
    except Exception as e:
        print(f"FAIL {f}: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
