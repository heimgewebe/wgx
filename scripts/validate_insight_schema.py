#!/usr/bin/env python3

import sys
import json
import logging
import argparse

# Configure logging to output to stderr
logging.basicConfig(level=logging.INFO, format='%(message)s', stream=sys.stderr)

def validate_insight(instance_path, schema_path):
    """
    Validates a Heimgeist insight JSON file against a provided JSON Schema.
    """
    try:
        # Import jsonschema here to allow script to fail gracefully if not installed
        # (though strictly required by plan, in some envs it might be missing)
        try:
            from jsonschema import validate
            from jsonschema.exceptions import ValidationError
        except ImportError:
            logging.error("Error: 'jsonschema' library is required. Install via 'uv pip install jsonschema'.")
            sys.exit(1)

        # Load Schema
        try:
            with open(schema_path, 'r') as sf:
                schema = json.load(sf)
        except Exception as e:
            logging.error(f"Failed to load schema from {schema_path}: {e}")
            sys.exit(1)

        # Load Instance
        try:
            with open(instance_path, 'r') as f:
                content = f.read().strip()

            # Handle Chronik log format: key=value
            try:
                data = json.loads(content)
            except json.JSONDecodeError:
                lines = content.splitlines()
                if not lines:
                    raise ValueError("Empty file")
                last_line = lines[-1]
                if '=' in last_line:
                    _, value = last_line.split('=', 1)
                    data = json.loads(value)
                else:
                    raise ValueError("Could not parse file as JSON or Key=Value pair")
        except Exception as e:
            logging.error(f"Failed to load instance from {instance_path}: {e}")
            sys.exit(1)

        # Validate
        try:
            validate(instance=data, schema=schema)
            logging.info("Schema Validation Passed")
            sys.exit(0)
        except ValidationError as e:
            logging.error(f"Schema Validation Failed: {e.message}")
            sys.exit(1)

    except Exception as e:
        logging.error(f"Validation process failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate JSON against a Schema")
    parser.add_argument("instance", help="Path to the JSON instance (or log file)")
    parser.add_argument("--schema", required=True, help="Path to the JSON Schema file")

    args = parser.parse_args()

    validate_insight(args.instance, args.schema)
