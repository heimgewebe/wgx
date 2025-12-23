#!/usr/bin/env python3

import sys
import json
import logging

# Configure logging to output to stderr
logging.basicConfig(level=logging.INFO, format='%(message)s', stream=sys.stderr)

def validate_insight(filepath):
    """
    Validates a Heimgeist insight JSON file against the Mini-Spec.
    """
    try:
        with open(filepath, 'r') as f:
            content = f.read().strip()

        # The chronik mock file might contain "key=value" lines or just raw JSON if we adapted it.
        # But wait, chronik.bash appends `key=value`.
        # The schema validation logic needs to handle that or we need to parse the file carefully.
        # For this script, let's assume it gets passed the raw JSON of the insight itself,
        # OR it parses the output of the mock file.

        # Let's support both: direct JSON file or parsing the LAST line of a chronik mock file.

        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            # Maybe it's a chronik log format: key=value
            lines = content.splitlines()
            if not lines:
                raise ValueError("Empty file")
            last_line = lines[-1]
            if '=' in last_line:
                _, value = last_line.split('=', 1)
                data = json.loads(value)
            else:
                raise ValueError("Could not parse file as JSON or Key=Value pair")

        # Validate Wrapper
        errors = []
        if data.get('kind') != 'heimgeist.insight':
            errors.append(f"Invalid kind: {data.get('kind')}")

        if data.get('version') != 1:
            errors.append(f"Invalid version: {data.get('version')}")

        if 'id' not in data:
            errors.append("Missing 'id'")

        if 'meta' not in data:
            errors.append("Missing 'meta'")
        else:
            meta = data['meta']
            if 'occurred_at' not in meta:
                errors.append("Missing 'meta.occurred_at'")
            # role is optional in my implementation (args passed), but spec says 'role' in meta.
            # My archivist implementation puts it there.
            if 'role' not in meta:
                errors.append("Missing 'meta.role'")

        if 'data' not in data:
            errors.append("Missing 'data'")

        if errors:
            for err in errors:
                logging.error(f"Schema Error: {err}")
            sys.exit(1)

        logging.info("Schema Validation Passed")
        sys.exit(0)

    except Exception as e:
        logging.error(f"Validation failed with exception: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        logging.error("Usage: validate_insight_schema.py <filepath>")
        sys.exit(1)

    validate_insight(sys.argv[1])
