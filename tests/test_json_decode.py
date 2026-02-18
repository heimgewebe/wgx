#!/usr/bin/env python3
import sys
import io
import unittest
from unittest.mock import patch
from modules import json_decode

class TestJsonDecode(unittest.TestCase):

    def test_decode_list(self):
        """Test decoding a standard JSON list."""
        with patch.object(sys, 'argv', ['json_decode.py', '["a", "b", "c"]']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                json_decode.main()
                self.assertEqual(mock_stdout.getvalue(), "a\nb\nc\n")

    def test_decode_with_null(self):
        """Test that null values are skipped."""
        with patch.object(sys, 'argv', ['json_decode.py', '["a", null, "b"]']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                json_decode.main()
                self.assertEqual(mock_stdout.getvalue(), "a\nb\n")

    def test_decode_mixed_types(self):
        """Test decoding mixed types, which should be converted to strings."""
        with patch.object(sys, 'argv', ['json_decode.py', '[1, true, 2.5]']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                json_decode.main()
                self.assertEqual(mock_stdout.getvalue(), "1\nTrue\n2.5\n")

    def test_decode_empty_list(self):
        """Test decoding an empty JSON list."""
        with patch.object(sys, 'argv', ['json_decode.py', '[]']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                json_decode.main()
                self.assertEqual(mock_stdout.getvalue(), "")

    def test_decode_invalid_json(self):
        """Test that invalid JSON causes exit with status 1."""
        with patch.object(sys, 'argv', ['json_decode.py', 'invalid-json']):
            with self.assertRaises(SystemExit) as cm:
                json_decode.main()
            self.assertEqual(cm.exception.code, 1)

    def test_decode_non_list(self):
        """Test that non-list JSON (e.g., dict) causes exit with status 1."""
        with patch.object(sys, 'argv', ['json_decode.py', '{"a": 1}']):
            with self.assertRaises(SystemExit) as cm:
                json_decode.main()
            self.assertEqual(cm.exception.code, 1)

    def test_decode_missing_arg(self):
        """Test that missing argument causes exit with status 1."""
        with patch.object(sys, 'argv', ['json_decode.py']):
            with self.assertRaises(SystemExit) as cm:
                json_decode.main()
            self.assertEqual(cm.exception.code, 1)

    def test_decode_nested_structures(self):
        """Test decoding a list containing nested structures (list and dict)."""
        with patch.object(sys, 'argv', ['json_decode.py', '[1, ["nested"], {"key": "value"}]']):
            with patch('sys.stdout', new=io.StringIO()) as mock_stdout:
                json_decode.main()
                self.assertEqual(mock_stdout.getvalue(), "1\n['nested']\n{'key': 'value'}\n")

if __name__ == '__main__':
    unittest.main()
