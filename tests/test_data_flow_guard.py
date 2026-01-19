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
        # Setup: Config exists, schema exists, data exists

        # Mocking exists:
        # 1. Config check (contracts/flows.yaml) -> True
        # 2. Schema check (path/to/schema.json) -> True
        # 3. Data check (path/to/data.json) -> True
        def exists_side_effect(p):
            if p == "contracts/flows.yaml": return True
            if p == "path/to/schema.json": return True
            if p == "path/to/data.json": return True
            return False
        mock_exists.side_effect = exists_side_effect

        mock_glob.return_value = [] # Assume exact path in data pattern

        config_content = """
flows:
  test_flow:
    schema: "path/to/schema.json"
    data: ["path/to/data.json"]
"""
        schema_content = '{"type": "object"}'
        data_content = '[{"id": "1", "val": "test"}]'

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if "flows.yaml" in file:
                return mock_open(read_data=config_content).return_value
            elif "schema.json" in file:
                return mock_open(read_data=schema_content).return_value
            elif "data.json" in file:
                return mock_open(read_data=data_content).return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        # Mock yaml.safe_load
        mock_yaml = MagicMock()
        mock_yaml.safe_load.return_value = {
            "flows": {
                "test_flow": {
                    "schema": "path/to/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        }

        with patch('guards.data_flow_guard.yaml', mock_yaml):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        # Verify validator was created
        self.assertTrue(mock_jsonschema.validators.validator_for.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_schema_missing_fail(self, mock_file, mock_exists, mock_jsonschema):
        # Setup: Config exists, Data exists, Schema MISSING -> Fail

        def exists_side_effect(p):
            if p == "contracts/flows.json": return True
            if p == "path/to/data.json": return True
            if p == "path/to/missing_schema.json": return False # Missing!
            return False
        mock_exists.side_effect = exists_side_effect

        config_content = json.dumps({
            "flows": {
                "broken_flow": {
                    "schema": "path/to/missing_schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if "flows.json" in file:
                return mock_open(read_data=config_content).return_value
            if "data.json" in file:
                return mock_open(read_data="[]").return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        # We need to simulate no yaml installed so it falls back to json check
        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 1)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_no_data_skip(self, mock_file, mock_exists, mock_jsonschema):
        # Setup: Config exists, Schema missing, BUT Data also missing -> OK (Skip)

        def exists_side_effect(p):
            if p == "contracts/flows.json": return True
            return False # Data matches nothing
        mock_exists.side_effect = exists_side_effect

        config_content = json.dumps({
            "flows": {
                "empty_flow": {
                    "schema": "path/to/schema.json",
                    "data": ["path/to/nowhere.json"]
                }
            }
        })

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': mock_open(read_data=config_content).return_value if "flows.json" in f else mock_open(read_data="").return_value

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

if __name__ == '__main__':
    unittest.main()
