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
        # Setup: Config exists at .wgx/flows.json (canonical), schema exists, data exists
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", ".wgx/contracts/schema.json", "path/to/data.json"]
        mock_glob.return_value = [] # Assume exact path

        config_content = json.dumps({
            "flows": {
                "test_flow": {
                    "schema": ".wgx/contracts/schema.json",
                    "data": ["path/to/data.json"]
                }
            }
        })
        schema_content = '{"type": "object"}'
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

        # Mock Validator and RefResolver
        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)
        # Ensure RefResolver exists
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_validator_instance.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_missing_ref_resolver_fail(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: RefResolver missing from jsonschema
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

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': mock_open(read_data=config_content).return_value if ".wgx/flows.json" in f else mock_open(read_data='{}').return_value

        # Delete RefResolver from mock
        del mock_jsonschema.RefResolver

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 1) # Should fail strict check

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_recursive_glob_fail(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        mock_exists.side_effect = lambda p: p == ".wgx/flows.json"

        config_content = json.dumps({
            "flows": {
                "recursive_flow": {
                    "schema": "path/to/schema.json",
                    "data": ["path/**/data.json"]
                }
            }
        })

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': mock_open(read_data=config_content).return_value

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 1)

    # load_data robustness tests
    def test_load_data_rejects_primitive_json(self):
        with patch("builtins.open", mock_open(read_data='"string"')):
            with self.assertRaises(ValueError):
                data_flow_guard.load_data("dummy")

    def test_load_data_accepts_object_and_array(self):
        with patch("builtins.open", mock_open(read_data='{"a": 1}')):
            data = data_flow_guard.load_data("dummy")
            self.assertEqual(data, [{"a": 1}])

if __name__ == '__main__':
    unittest.main()
