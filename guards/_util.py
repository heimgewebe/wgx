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
