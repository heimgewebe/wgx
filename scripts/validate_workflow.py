#!/usr/bin/env python3
import sys
from pathlib import Path

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


def main():
    if len(sys.argv) < 2:
        print("Usage: validate_workflow.py <path_to_workflow.yml>")
        sys.exit(1)

    f = sys.argv[1]

    if not HAS_YAML:
        print(f"FAIL {f}: 'PyYAML' library is required. Install via 'uv pip install PyYAML'.")
        sys.exit(1)

    try:
        path = Path(f)
        if not path.exists():
            print(f"FAIL {f}: File not found")
            sys.exit(1)

        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise TypeError("workflow root must be a mapping")
        print(f"OK   {f}")
    except Exception as e:
        print(f"FAIL {f}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
