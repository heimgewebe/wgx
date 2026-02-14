import json

def safe_item_id(item, i):
    """
    Extract a stable ID from a guard item.

    Args:
        item: The data item (dict or other).
        i: The index of the item in the list.

    Returns:
        item["id"] if item is a dict and has "id", otherwise "item-{i}".
    """
    if isinstance(item, dict) and "id" in item:
        return item["id"]
    return f"item-{i}"

def load_data(filepath):
    """
    Load data from JSON or JSONL file.
    Returns a list of items or raises an exception.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        # Try JSON first
        try:
            data = json.load(f)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                return [data]
            else:
                # Valid JSON but wrong shape (e.g. primitive) – surface as error so
                # callers do not silently skip validation.
                raise ValueError(
                    "File content must be a JSON object or array (got primitive value)"
                )
        except json.JSONDecodeError:
            # Try JSONL
            f.seek(0)
            items = []

            for i, line in enumerate(f):
                line = line.strip()
                if not line:
                    continue
                try:
                    items.append(json.loads(line))
                except json.JSONDecodeError as e:
                    # Provide clearer error context for operator
                    raise ValueError(f"Line {i+1}: invalid JSON: {e}")

            # If we reached here, either file is empty, whitespace only, or we parsed some lines.
            # If no valid lines were found, it's an empty or whitespace-only file (since invalid lines raise).
            # We return empty list in that case.
            return items
