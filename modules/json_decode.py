#!/usr/bin/env python3
import json
import sys


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    try:
        values = json.loads(sys.argv[1])
    except (json.JSONDecodeError, TypeError):
        sys.exit(1)

    if not isinstance(values, list):
        sys.exit(1)

    for entry in values:
        if entry is None:
            continue
        print(str(entry))


if __name__ == "__main__":
    main()
