import json
import os
import pytest

jsonschema = pytest.importorskip("jsonschema")

SCHEMA_PATH = "contracts/insights.schema.json"

@pytest.fixture
def schema():
    if not os.path.exists(SCHEMA_PATH):
        pytest.fail(f"Schema file not found: {SCHEMA_PATH}")
    with open(SCHEMA_PATH, 'r') as f:
        return json.load(f)

def test_schema_valid_negation(schema):
    item = {
        "type": "insight.negation",
        "relation": {
            "thesis": "A",
            "antithesis": "B"
        }
    }
    jsonschema.validate(item, schema)

def test_schema_invalid_negation_missing_relation(schema):
    item = {
        "type": "insight.negation"
    }
    with pytest.raises(jsonschema.ValidationError) as excinfo:
        jsonschema.validate(item, schema)
    assert "'relation' is a required property" in str(excinfo.value)

def test_schema_invalid_negation_missing_thesis(schema):
    item = {
        "type": "insight.negation",
        "relation": {
            "antithesis": "B"
        }
    }
    with pytest.raises(jsonschema.ValidationError) as excinfo:
        jsonschema.validate(item, schema)
    assert "'thesis' is a required property" in str(excinfo.value)

def test_schema_invalid_negation_missing_antithesis(schema):
    item = {
        "type": "insight.negation",
        "relation": {
            "thesis": "A"
        }
    }
    with pytest.raises(jsonschema.ValidationError) as excinfo:
        jsonschema.validate(item, schema)
    assert "'antithesis' is a required property" in str(excinfo.value)

def test_schema_valid_other_type(schema):
    item = {
        "type": "insight.other",
        "foo": "bar"
    }
    jsonschema.validate(item, schema)

def test_schema_invalid_missing_type(schema):
    item = {
        "foo": "bar"
    }
    with pytest.raises(jsonschema.ValidationError) as excinfo:
        jsonschema.validate(item, schema)
    assert "'type' is a required property" in str(excinfo.value)
