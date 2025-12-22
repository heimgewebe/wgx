#!/usr/bin/env python3
import sys
import os
import io
import unittest
from unittest.mock import patch, mock_open

# Adjust path to import modules/profile_parser.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../modules')))

import profile_parser

class TestProfileParser(unittest.TestCase):

    def test_split_key_value_standard(self):
        """Test standard 'key: value' splitting."""
        self.assertEqual(profile_parser._split_key_value("key: value"), ("key", " value"))
        self.assertEqual(profile_parser._split_key_value("key:   value"), ("key", "   value"))

    def test_split_key_value_url(self):
        """Test that URLs (colon without space) are NOT split."""
        self.assertIsNone(profile_parser._split_key_value("http://example.com"))
        self.assertIsNone(profile_parser._split_key_value("https://example.com/foo:bar"))

    def test_split_key_value_compact(self):
        """Test that 'key:value' (no space) is NOT split (treated as string)."""
        self.assertIsNone(profile_parser._split_key_value("key:value"))
        self.assertIsNone(profile_parser._split_key_value("image:tag"))

    def test_split_key_value_end_of_line(self):
        """Test 'key:' at end of line is split."""
        self.assertEqual(profile_parser._split_key_value("key:"), ("key", ""))
        self.assertEqual(profile_parser._split_key_value("'key':"), ("'key'", ""))

    def test_split_key_value_quoted(self):
        """Test quoted keys."""
        self.assertEqual(profile_parser._split_key_value("'key': value"), ("'key'", " value"))
        self.assertEqual(profile_parser._split_key_value('"key": value'), ('"key"', " value"))
        self.assertEqual(profile_parser._split_key_value("'key:complex': value"), ("'key:complex'", " value"))

    def test_split_key_value_quoted_values(self):
        """Test quoted values containing colons."""
        self.assertEqual(profile_parser._split_key_value("key: 'http://example.com'"), ("key", " 'http://example.com'"))

    def test_strip_inline_comment_standard(self):
        """Test standard comment stripping."""
        self.assertEqual(profile_parser._strip_inline_comment("value # comment"), "value ")

    def test_strip_inline_comment_compact_hash(self):
        """Test that 'value#comment' is NOT stripped (must have space)."""
        # This is expected to FAIL until we fix the implementation
        self.assertEqual(profile_parser._strip_inline_comment("value#comment"), "value#comment")

    def test_strip_inline_comment_quoted(self):
        """Test that hashes inside quotes are preserved."""
        self.assertEqual(profile_parser._strip_inline_comment("val '# not comment'"), "val '# not comment'")
        self.assertEqual(profile_parser._strip_inline_comment('val "# not comment"'), 'val "# not comment"')

    def test_strip_inline_comment_start(self):
        """Test comments at start of line."""
        self.assertEqual(profile_parser._strip_inline_comment("# comment"), "")
        self.assertEqual(profile_parser._strip_inline_comment("   # comment"), "   ")

    def test_main_missing_args(self):
        """Test that main() exits with status 1 if arguments are missing."""
        with patch.object(sys, 'argv', ['profile_parser.py']):
            # We also mock stderr to avoid cluttering the test output
            with patch('sys.stderr', new=io.StringIO()) as mock_stderr:
                with self.assertRaises(SystemExit) as cm:
                    profile_parser.main()
                self.assertEqual(cm.exception.code, 1)
                self.assertIn("Usage:", mock_stderr.getvalue())

if __name__ == '__main__':
    unittest.main()
