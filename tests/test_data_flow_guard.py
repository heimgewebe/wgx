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
            if ".wgx/flows.json" in str(file):
                return mock_open(read_data=config_content).return_value
            elif "schema.json" in str(file):
                return mock_open(read_data=schema_content).return_value
            elif "data.json" in str(file):
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
            if ".yml" in str(file):
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
            mock_open(read_data=config_content).return_value if "flows.json" in str(f) else \
            mock_open(read_data=data_content).return_value if "data.json" in str(f) else \
            mock_open(read_data='{}').return_value

        mock_validator = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator)
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        # Verify validation was called on string item without crash
        mock_validator.validate.assert_called_with("valid_string_item")

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_schema_caching(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Goal: Verify that when two flows use the same schema, the schema is loaded only once.
        schema_path = ".wgx/contracts/shared_schema.json"

        # Setup: 2 flows, same schema, distinct data
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", schema_path, "data1.json", "data2.json"]
        mock_glob.return_value = [] # No glob expansion needed

        config_content = json.dumps([
            {
                "name": "flow1",
                "schema_path": schema_path,
                "data_pattern": ["data1.json"]
            },
            {
                "name": "flow2",
                "schema_path": schema_path,
                "data_pattern": ["data2.json"]
            }
        ])

        # Use a dummy content
        schema_content = '{"type": "object", "properties": {"val": {"type": "string"}}}'
        data1_content = '[{"id": "d1", "val": "one"}]'
        data2_content = '[{"id": "d2", "val": "two"}]'

        def open_side_effect(file, mode='r', encoding='utf-8'):
            s_file = str(file)
            if ".wgx/flows.json" in s_file:
                return mock_open(read_data=config_content).return_value
            elif "shared_schema.json" in s_file:
                return mock_open(read_data=schema_content).return_value
            elif "data1.json" in s_file:
                return mock_open(read_data=data1_content).return_value
            elif "data2.json" in s_file:
                return mock_open(read_data=data2_content).return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        # Mock Validator
        mock_validator_instance = MagicMock()
        mock_validator_cls = MagicMock(return_value=mock_validator_instance)
        mock_jsonschema.validators.validator_for.return_value = mock_validator_cls
        mock_jsonschema.RefResolver = MagicMock()

        # Run main without patching yaml (not needed for this test)
        ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # Assertions

        # 1. Schema file should be opened exactly once (despite 2 flows)
        schema_open_calls = [
            str(args[0])
            for args, kwargs in mock_file.call_args_list
            if "shared_schema.json" in str(args[0])
        ]

        self.assertEqual(
            len(schema_open_calls),
            1,
            f"Expected schema to be opened exactly once, but was opened {len(schema_open_calls)} times: {schema_open_calls}"
        )

        # 2. Validator class/factory should be accessed exactly once
        self.assertEqual(mock_jsonschema.validators.validator_for.call_count, 1,
                         f"Expected validator_for to be called exactly once, but was {mock_jsonschema.validators.validator_for.call_count}")

        # 3. Validation should happen twice (once for d1, once for d2)
        # Since we use the same validator instance (cached), we check calls on it.
        self.assertEqual(mock_validator_instance.validate.call_count, 2, "Expected validate to be called twice (once per flow)")

        # Verify it validated both items
        calls = mock_validator_instance.validate.mock_calls
        args_list = [c[1][0] for c in calls]
        self.assertIn({"id": "d1", "val": "one"}, args_list)
        self.assertIn({"id": "d2", "val": "two"}, args_list)

if __name__ == '__main__':
    unittest.main()
