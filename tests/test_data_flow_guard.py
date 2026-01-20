import unittest
from unittest.mock import patch, mock_open, MagicMock
import sys
import os
import json

# Ensure the guard can be imported
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from guards import data_flow_guard

class TestDataFlowGuard(unittest.TestCase):

    @patch('guards.data_flow_guard.jsonschema', None)
    def test_main_skip_no_jsonschema(self):
        ret = data_flow_guard.main()
        self.assertEqual(ret, 0)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_happy_path(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: Config exists at .wgx/flows.json, schema exists, data exists
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", ".wgx/contracts/schema.json", "path/to/data.json"]
        mock_glob.return_value = []

        config_content = json.dumps({
            "flows": {
                "test_flow": {
                    "schema": ".wgx/contracts/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })
        schema_content = '{"type": "object"}' # No $ref
        data_content = '[{"id": "1", "val": "test"}]'

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if ".wgx/flows.json" in file:
                return mock_open(read_data=config_content).return_value
            elif "schema.json" in file:
                return mock_open(read_data=schema_content).return_value
            elif "data.json" in file:
                return mock_open(read_data=data_content).return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)
        # RefResolver present in happy path
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_validator_instance.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_missing_ref_resolver_simple_schema_pass(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: RefResolver missing, but schema has no $ref -> Pass
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", ".wgx/contracts/schema.json", "path/to/data.json"]
        mock_glob.return_value = []

        config_content = json.dumps({
            "flows": {
                "test_flow": {
                    "schema": ".wgx/contracts/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })
        schema_content = '{"type": "object", "properties": {"val": {"type": "string"}}}' # No $ref

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': \
            mock_open(read_data=config_content).return_value if ".wgx/flows.json" in f else \
            mock_open(read_data=schema_content).return_value if "schema.json" in f else \
            mock_open(read_data='{}').return_value

        # Delete RefResolver
        del mock_jsonschema.RefResolver

        mock_validator_instance = MagicMock()
        # Mock validator constructor call which might happen differently
        mock_class = MagicMock(return_value=mock_validator_instance)
        mock_jsonschema.validators.validator_for.return_value = mock_class

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_validator_instance.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_missing_ref_resolver_complex_schema_fail(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: RefResolver missing AND schema has $ref -> Fail
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", ".wgx/contracts/schema.json", "path/to/data.json"]
        mock_glob.return_value = []

        config_content = json.dumps({
            "flows": {
                "test_flow": {
                    "schema": ".wgx/contracts/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })
        schema_content = '{"type": "object", "properties": {"val": {"$ref": "#/defs/val"}}}' # Has $ref

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': \
            mock_open(read_data=config_content).return_value if ".wgx/flows.json" in f else \
            mock_open(read_data=schema_content).return_value if "schema.json" in f else \
            mock_open(read_data='{}').return_value

        del mock_jsonschema.RefResolver

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 1)

    # load_data tests
    def test_load_data_rejects_primitive_json(self):
        with patch("builtins.open", mock_open(read_data='"string"')):
            with self.assertRaises(ValueError):
                data_flow_guard.load_data("dummy")

if __name__ == '__main__':
    unittest.main()
