import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import guards.insights_guard as insights_guard


def test_load_data_rejects_primitive_json(tmp_path: Path):
    sample = tmp_path / "primitive.json"
    sample.write_text("42", encoding="utf-8")

    with pytest.raises(ValueError):
        insights_guard.load_data(sample)


def test_load_data_accepts_object_and_array(tmp_path: Path):
    obj_file = tmp_path / "object.json"
    obj_file.write_text(json.dumps({"id": 1}), encoding="utf-8")
    array_file = tmp_path / "array.json"
    array_file.write_text(json.dumps([{"id": 2}]), encoding="utf-8")

    assert insights_guard.load_data(obj_file) == [{"id": 1}]
    assert insights_guard.load_data(array_file) == [{"id": 2}]
