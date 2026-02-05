def safe_item_id(item, i):
    if isinstance(item, dict) and "id" in item:
        return item["id"]
    return f"item-{i}"
