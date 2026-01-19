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
        mock_exists.side_effect = lambda p: p in ["contracts/flows.yaml", "path/to/schema.json", "path/to/data.json"]
        mock_glob.return_value = [] # Assume exact path

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

        mock_yaml = MagicMock()
        mock_yaml.safe_load.return_value = {
            "flows": {
                "test_flow": {
                    "schema": "path/to/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        }

        # Mock Validator
        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)

        with patch('guards.data_flow_guard.yaml', mock_yaml):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_validator_instance.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_schema_missing_fail(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        mock_exists.side_effect = lambda p: p in ["contracts/flows.json", "path/to/data.json"]
        mock_glob.return_value = []

        config_content = json.dumps({
            "flows": {
                "broken_flow": {
                    "schema": "path/to/missing_schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': mock_open(read_data=config_content).return_value if "flows.json" in f else mock_open(read_data="[]").return_value

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 1)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_no_data_skip(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        mock_exists.side_effect = lambda p: p == "contracts/flows.json"
        mock_glob.return_value = []

        config_content = json.dumps({
            "flows": {
                "empty_flow": {
                    "schema": "path/to/schema.json",
                    "data": ["path/to/nowhere.json"]
                }
            }
        })

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': mock_open(read_data=config_content).return_value

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

    # load_data robustness tests
    def test_load_data_rejects_primitive_json(self):
        with patch("builtins.open", mock_open(read_data='"string"')):
            with self.assertRaises(ValueError):
                data_flow_guard.load_data("dummy")
        with patch("builtins.open", mock_open(read_data='123')):
            with self.assertRaises(ValueError):
                data_flow_guard.load_data("dummy")
        with patch("builtins.open", mock_open(read_data='true')):
            with self.assertRaises(ValueError):
                data_flow_guard.load_data("dummy")

    def test_load_data_accepts_object_and_array(self):
        with patch("builtins.open", mock_open(read_data='{"a": 1}')):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(data, [{"a": 1}])
        with patch("builtins.open", mock_open(read_data='[{"a": 1}]')):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(data, [{"a": 1}])

    def test_load_data_accepts_jsonl(self):
        content = '{"a": 1}\n{"b": 2}'
        with patch("builtins.open", mock_open(read_data=content)):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(len(data), 2)
            self.assertEqual(data[0], {"a": 1})

    def test_load_data_jsonl_reports_line_number(self):
        content = '{"a": 1}\nBROKEN_JSON'
        with patch("builtins.open", mock_open(read_data=content)):
            with self.assertRaisesRegex(ValueError, "Line 2"):
                data_flow_guard.load_data("dummy")

    def test_load_data_empty_file(self):
         # Assuming explicit empty file is invalid JSON/JSONL based on implementation
         # (content.strip() is empty -> "neither valid JSON nor valid JSONL" if valid_lines_count is 0 is NOT reached if content empty)
         # Wait, logic: if content.strip() and valid_lines_count == 0 -> Error.
         # If content is empty -> splitlines is empty -> returns [].
         # Let's verify what we want. Usually empty file = empty list.
         with patch("builtins.open", mock_open(read_data='')):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(data, [])

         # Whitespace only
         with patch("builtins.open", mock_open(read_data='   ')):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(data, [])

if __name__ == '__main__':
    unittest.main()
