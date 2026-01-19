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
        # Logic relies on module-level variable which is set at import time.
        # But we can patch the variable in the module.
        ret = data_flow_guard.main()
        self.assertEqual(ret, 0)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_happy_path(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: schema exists, data exists for observatory flow
        mock_exists.side_effect = lambda p: p in ["contracts/knowledge.observatory.schema.json", "artifacts/knowledge.observatory.json"]
        mock_glob.return_value = []

        schema_content = '{"type": "object"}'
        data_content = '[{"id": "1", "val": "test"}]'

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if "schema" in file:
                return mock_open(read_data=schema_content).return_value
            elif "artifacts" in file:
                return mock_open(read_data=data_content).return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        ret = data_flow_guard.main()

        self.assertEqual(ret, 0)
        self.assertTrue(mock_jsonschema.validate.called)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_validation_error(self, mock_file, mock_exists, mock_jsonschema):
        # Setup: schema exists, data exists
        mock_exists.side_effect = lambda p: p in ["contracts/knowledge.observatory.schema.json", "artifacts/knowledge.observatory.json"]

        schema_content = '{"type": "object"}'
        data_content = '[{"id": "1", "val": "test"}]'

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if "schema" in file:
                return mock_open(read_data=schema_content).return_value
            else:
                return mock_open(read_data=data_content).return_value

        mock_file.side_effect = open_side_effect

        # Configure Mock ValidationError
        # The script catches jsonschema.ValidationError
        # We need to ensure the raised exception is caught
        class ValidationError(Exception):
            message = "Invalid data"

        mock_jsonschema.ValidationError = ValidationError
        mock_jsonschema.validate.side_effect = ValidationError()

        ret = data_flow_guard.main()

        self.assertEqual(ret, 1)

    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    def test_main_skip_no_files(self, mock_exists, mock_jsonschema):
        # Setup: Nothing exists
        mock_exists.return_value = False
        ret = data_flow_guard.main()
        self.assertEqual(ret, 0)
        self.assertFalse(mock_jsonschema.validate.called)

if __name__ == '__main__':
    unittest.main()
