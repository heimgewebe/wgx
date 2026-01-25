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
        with patch.dict(os.environ, {}, clear=True):
            ret = data_flow_guard.main()
            self.assertEqual(ret, 0)

    @patch('guards.data_flow_guard.jsonschema', None)
    def test_main_fail_strict_no_jsonschema(self):
        with patch.dict(os.environ, {"WGX_STRICT": "1"}):
            ret = data_flow_guard.main()
            self.assertEqual(ret, 1)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_happy_path(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: Config exists at .wgx/flows.json, schema exists, data exists
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", ".wgx/contracts/schema.json", "path/to/data.json"]
        mock_glob.return_value = []

        config_content = json.dumps([
            {
                "name": "test_flow",
                "schema_path": ".wgx/contracts/schema.json",
                "data_pattern": ["path/to/data.json"]
            }
        ])
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

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_validator_instance.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_yaml_config_loading(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: Config exists at .wgx/flows.yml
        mock_exists.side_effect = lambda p: p in [".wgx/flows.yml", "schema.json", "data.json"]
        mock_glob.return_value = []

        # Mock yaml.safe_load return
        config_data = [
            {
                "name": "yaml_flow",
                "schema_path": "schema.json",
                "data_pattern": ["data.json"]
            }
        ]

        mock_yaml = MagicMock()
        mock_yaml.safe_load.return_value = config_data

        # We need to ensure open() is called for .yml
        def open_side_effect(file, mode='r', encoding='utf-8'):
            if ".yml" in file:
                return mock_open(read_data="dummy").return_value
            return mock_open(read_data='{}').return_value # Schema/Data empty valid json

        mock_file.side_effect = open_side_effect

        with patch('guards.data_flow_guard.yaml', mock_yaml):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        mock_yaml.safe_load.assert_called()

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_safe_id_extraction(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: Data contains non-dict item (e.g. string)
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", "schema.json", "data.json"]
        mock_glob.return_value = []

        config_content = json.dumps([{"name":"f", "schema_path":"schema.json", "data_pattern":["data.json"]}])
        data_content = '["valid_string_item"]' # Not a dict!

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': \
            mock_open(read_data=config_content).return_value if "flows.json" in f else \
            mock_open(read_data=data_content).return_value if "data.json" in f else \
            mock_open(read_data='{}').return_value

        mock_validator = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator)
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        # Verify validation was called on string item without crash
        mock_validator.validate.assert_called_with("valid_string_item")

if __name__ == '__main__':
    unittest.main()
