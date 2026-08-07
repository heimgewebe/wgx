import json
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

ROOT = Path(__file__).resolve().parents[1]


def _validator() -> Draft7Validator:
    schema = json.loads((ROOT / "docs" / "profile.schema.json").read_text(encoding="utf-8"))
    Draft7Validator.check_schema(schema)
    return Draft7Validator(schema)


def test_current_profile_examples_match_compatibility_schema() -> None:
    validator = _validator()
    for path in (ROOT / ".wgx" / "profile.example.yml", ROOT / "fixtures" / "profile.valid.yml"):
        validator.validate(yaml.safe_load(path.read_text(encoding="utf-8")))


def test_legacy_root_tasks_remain_accepted_during_cutover() -> None:
    _validator().validate({"tasks": {"smoke": "echo ok"}})


def test_conflicting_old_required_root_shape_is_not_required() -> None:
    payload = {"wgx": {"apiVersion": "v1", "tasks": {"smoke": "echo ok"}}}
    _validator().validate(payload)
    assert "profile" not in payload and "description" not in payload and "class" not in payload
