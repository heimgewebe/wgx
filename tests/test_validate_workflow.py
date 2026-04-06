#!/usr/bin/env python3
import sys
import io
import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock

# Import the module to test. We'll need to patch 'HAS_YAML' and 'yaml'
from scripts import validate_workflow

class TestValidateWorkflow(unittest.TestCase):

    def setUp(self):
        # Default behavior: pretend PyYAML is present
        self.mock_yaml = MagicMock()
        # Use patch.dict to safely inject 'yaml' into the module
        self.has_yaml_patch = patch('scripts.validate_workflow.HAS_YAML', True)
        self.has_yaml_patch.start()

    def tearDown(self):
        self.has_yaml_patch.stop()

    def test_valid_workflow(self):
        """Test with a valid workflow file."""
        with patch('scripts.validate_workflow.yaml', self.mock_yaml, create=True):
            self.mock_yaml.safe_load.return_value = {"name": "test-workflow"}
            with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".yml") as tmp:
                tmp.write("name: test-workflow\non: push\n")
                tmp_path = tmp.name

            try:
                with patch.object(sys, 'argv', ['validate_workflow.py', tmp_path]):
                    with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                        validate_workflow.main()
                        self.assertIn(f"OK   {tmp_path}", mock_stdout.getvalue())
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)

    def test_invalid_type_workflow(self):
        """Test with a YAML file that is not a dictionary (e.g., a list)."""
        with patch('scripts.validate_workflow.yaml', self.mock_yaml, create=True):
            self.mock_yaml.safe_load.return_value = ["item1", "item2"]
            with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".yml") as tmp:
                tmp.write("- item1\n- item2\n")
                tmp_path = tmp.name

            try:
                with patch.object(sys, 'argv', ['validate_workflow.py', tmp_path]):
                    with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                        with self.assertRaises(SystemExit) as cm:
                            validate_workflow.main()
                        self.assertEqual(cm.exception.code, 1)
                        self.assertIn("FAIL", mock_stdout.getvalue())
                        self.assertIn("workflow root must be a mapping", mock_stdout.getvalue())
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)

    def test_missing_file(self):
        """Test with a non-existent file path."""
        with patch('scripts.validate_workflow.yaml', self.mock_yaml, create=True):
            with patch.object(sys, 'argv', ['validate_workflow.py', 'non_existent.yml']):
                with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                    with self.assertRaises(SystemExit) as cm:
                        validate_workflow.main()
                    self.assertEqual(cm.exception.code, 1)
                    self.assertIn("FAIL", mock_stdout.getvalue())
                    self.assertIn("File not found", mock_stdout.getvalue())

    def test_no_arguments(self):
        """Test execution without any arguments."""
        with patch.object(sys, 'argv', ['validate_workflow.py']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                with self.assertRaises(SystemExit) as cm:
                    validate_workflow.main()
                self.assertEqual(cm.exception.code, 1)
                self.assertIn("Usage:", mock_stdout.getvalue())

    def test_missing_pyyaml_library(self):
        """Test the case where PyYAML library is not installed."""
        # Use patch.dict to safely ensure HAS_YAML is False and 'yaml' is not used
        with patch('scripts.validate_workflow.HAS_YAML', False):
            with patch.object(sys, 'argv', ['validate_workflow.py', 'some_file.yml']):
                with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                    with self.assertRaises(SystemExit) as cm:
                        validate_workflow.main()
                    self.assertEqual(cm.exception.code, 1)
                    self.assertIn("PyYAML' library is required", mock_stdout.getvalue())

if __name__ == '__main__':
    unittest.main()
