#!/usr/bin/env python3
import glob, sys, pathlib

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required but not installed.")
    sys.exit(1)

files = list(glob.glob('.github/workflows/*.yml')) + \
        list(glob.glob('.github/workflows/*.yaml'))
if not files:
    print("No workflows found, skipping.")
    sys.exit(0)
for f in files:
    try:
        data = yaml.safe_load(pathlib.Path(f).read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise TypeError("workflow root must be a mapping")
        print(f"OK   {f}")
    except Exception as e:
        print(f"FAIL {f}: {e}")
        sys.exit(1)
print("All workflows valid.")
