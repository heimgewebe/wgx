#!/usr/bin/env python3
import sys
import os
import io
import unittest
import tempfile
import subprocess
from unittest.mock import patch, mock_open
from pathlib import Path

from modules import profile_parser

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
        # _split_key_value returns raw string parts.
        # The stripping of quotes happens in _parse_simple_yaml, but _split_key_value
        # should return them intact so the caller can identify them as keys.
        self.assertEqual(profile_parser._split_key_value("'key': value"), ("'key'", " value"))
        self.assertEqual(profile_parser._split_key_value('"key": value'), ('"key"', " value"))
        self.assertEqual(profile_parser._split_key_value("'key:complex': value"), ("'key:complex'", " value"))

    def test_integration_quoted_keys(self):
        """Test full parsing of quoted keys via _parse_simple_yaml."""
        # Create a temp file
        with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".yml") as tmp:
            tmp.write('"key1": value1\n')
            tmp.write("'key2': value2\n")
            tmp.write("key3: value3\n")
            tmp_path = tmp.name

        try:
            res = profile_parser._parse_simple_yaml(tmp_path)
            # Ensure quotes are stripped from keys
            self.assertIn("key1", res)
            self.assertIn("key2", res)
            self.assertIn("key3", res)
            self.assertEqual(res["key1"], "value1")
            self.assertEqual(res["key2"], "value2")
            self.assertEqual(res["key3"], "value3")
            # Ensure raw quoted keys are NOT present
            self.assertNotIn('"key1"', res)
            self.assertNotIn("'key2'", res)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_split_key_value_quoted_values(self):
        """Test quoted values containing colons."""
        self.assertEqual(profile_parser._split_key_value("key: 'http://example.com'"), ("key", " 'http://example.com'"))

    def test_strip_inline_comment_standard(self):
        """Test standard comment stripping."""
        self.assertEqual(profile_parser._strip_inline_comment("value # comment"), "value ")

    def test_strip_inline_comment_compact_hash(self):
        """Inline comments must be preceded by whitespace (space/tab); otherwise treated as literal."""
        self.assertEqual(profile_parser._strip_inline_comment("value#comment"), "value#comment")

    def test_strip_inline_comment_mixed(self):
        """Test mixed usage of compact hash (literal) and spaced hash (comment)."""
        self.assertEqual(profile_parser._strip_inline_comment("value#hash # comment"), "value#hash ")

    def test_strip_inline_comment_tabs(self):
        """Test that tabs count as whitespace for inline comments."""
        self.assertEqual(profile_parser._strip_inline_comment("value\t# comment"), "value\t")

    def test_strip_inline_comment_double_quoted_hash(self):
        """Hashes inside double quotes are preserved."""
        self.assertEqual(profile_parser._strip_inline_comment('"foo # bar"'), '"foo # bar"')

    def test_strip_inline_comment_hash_in_quotes_then_comment(self):
        """Test hash in quotes followed by a real comment."""
        self.assertEqual(profile_parser._strip_inline_comment('"foo # bar" # comment'), '"foo # bar" ')

    def test_strip_inline_comment_quoted(self):
        """Test that hashes inside quotes are preserved."""
        self.assertEqual(profile_parser._strip_inline_comment("val '# not comment'"), "val '# not comment'")
        self.assertEqual(profile_parser._strip_inline_comment('val "# not comment"'), 'val "# not comment"')

    def test_strip_inline_comment_start(self):
        """Test comments at start of line."""
        self.assertEqual(profile_parser._strip_inline_comment("# comment"), "")
        self.assertEqual(profile_parser._strip_inline_comment("   # comment"), "   ")

    def test_shell_quote_multiline_is_one_line_and_round_trips(self):
        value = "echo one\nprintf '%s\n' 'two'\necho $(literal)"

        quoted = profile_parser.shell_quote(value)

        self.assertNotIn("\n", quoted)
        self.assertTrue(quoted.startswith("$'"))
        completed = subprocess.run(
            ["bash", "-c", f"value={quoted}; printf %s \"$value\""],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.stdout, value)

    def test_shell_quote_uses_one_ansi_c_word_for_unsafe_values(self):
        for value in ("", "two words", "it's safe", "$(literal)"):
            quoted = profile_parser.shell_quote(value)
            self.assertTrue(quoted.startswith("$'"), quoted)
            self.assertTrue(quoted.endswith("'"), quoted)
            self.assertNotIn("'\"'\"'", quoted)

    def test_simple_token_with_plus_equals_round_trips(self):
        quoted = profile_parser.shell_quote("foo+=bar")
        self.assertEqual(quoted, "foo+=bar")
        completed = subprocess.run(
            ["bash", "-c", f"source modules/profile.bash; profile::_apply_parser_line 'VALUE={quoted}'; printf %s \"$VALUE\""],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.stdout, "foo+=bar")

    def test_emit_var_rejects_invalid_shell_name(self):
        with self.assertRaisesRegex(ValueError, "invalid shell variable name"):
            profile_parser.emit_var("WGX_SAFE=$(touch /tmp/nope)", "value")

    def test_emit_env_rejects_invalid_environment_key(self):
        with self.assertRaisesRegex(ValueError, "invalid environment key"):
            profile_parser.emit_env(
                "WGX_ENV_BASE_MAP",
                {"SAFE=$'x'$(touch /tmp/nope)$'y'": "value"},
            )

    def test_profile_loader_runs_multiline_task_with_single_quotes(self):
        root = Path(__file__).resolve().parents[1]
        content = (
            "tasks:\n"
            "  smoke: |\n"
            "    printf '%s\\n' one\n"
            "    printf '%s\\n' 'two words'\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            profile_dir = Path(tmp_dir) / ".wgx"
            profile_dir.mkdir()
            (profile_dir / "profile.yml").write_text(content, encoding="utf-8")
            script = (
                "set -euo pipefail; "
                f"source {profile_parser.shell_quote(str(root / 'lib' / 'core.bash'))}; "
                f"source {profile_parser.shell_quote(str(root / 'modules' / 'profile.bash'))}; "
                f"cd {profile_parser.shell_quote(tmp_dir)}; "
                "WGX_PROFILE_DEPRECATION=quiet; export WGX_PROFILE_DEPRECATION; "
                "profile::load .wgx/profile.yml; profile::run_task smoke"
            )
            completed = subprocess.run(
                ["bash", "-c", script],
                check=True,
                capture_output=True,
                text=True,
            )
        self.assertEqual(completed.stdout, "one\ntwo words\n")

    def test_profile_loader_accepts_python_tokens_inside_quoted_task_value(self):
        root = Path(__file__).resolve().parents[1]
        content = (
            "wgx:\n"
            "  tasks:\n"
            "    smoke: |\n"
            "      python3 - <<'PY'\n"
            "      import os\n"
            "      try:\n"
            "          print(os.environ.get('HOME'))\n"
            "      except Exception:\n"
            "          raise\n"
            "      PY\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            profile_dir = Path(tmp_dir) / ".wgx"
            profile_dir.mkdir()
            (profile_dir / "profile.yml").write_text(content, encoding="utf-8")
            script = (
                "set -euo pipefail; "
                f"source {profile_parser.shell_quote(str(root / 'lib' / 'core.bash'))}; "
                f"source {profile_parser.shell_quote(str(root / 'modules' / 'profile.bash'))}; "
                f"cd {profile_parser.shell_quote(tmp_dir)}; "
                "WGX_PROFILE_DEPRECATION=quiet; export WGX_PROFILE_DEPRECATION; "
                "profile::load .wgx/profile.yml; printf %s \"${WGX_TASK_CMDS[smoke]}\""
            )
            completed = subprocess.run(
                ["bash", "-c", script],
                check=True,
                capture_output=True,
                text=True,
            )
        expected = (
            "STR:python3 - <<'PY'\n"
            "import os\n"
            "try:\n"
            "    print(os.environ.get('HOME'))\n"
            "except Exception:\n"
            "    raise\n"
            "PY\n"
        )
        self.assertEqual(completed.stdout, expected)
        self.assertIn("print(", completed.stdout)
        self.assertIn("import os", completed.stdout)

    def test_main_missing_args(self):
        """Test that main() exits with status 1 if arguments are missing."""
        with patch.object(sys, 'argv', ['profile_parser.py']):
            # We also mock stderr to avoid cluttering the test output
            with patch('sys.stderr', new=io.StringIO()) as mock_stderr:
                with self.assertRaises(SystemExit) as cm:
                    profile_parser.main()
                self.assertEqual(cm.exception.code, 1)
                self.assertIn("Usage:", mock_stderr.getvalue())

    def test_task_name_collision(self):
        """Task names that normalize to the same key should error."""
        content = (
            "wgx:\n"
            "  tasks:\n"
            "    foo-bar:\n"
            "      cmd: echo foo\n"
            "    foo_bar:\n"
            "      cmd: echo bar\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = os.path.join(tmp_dir, "profile.yml")
            with open(tmp_path, "w", encoding="utf-8") as handle:
                handle.write(content)
            with patch.object(sys, 'argv', ['profile_parser.py', tmp_path]):
                with patch('sys.stderr', new=io.StringIO()) as mock_stderr:
                    with self.assertRaises(SystemExit) as cm:
                        profile_parser.main()
                    self.assertEqual(cm.exception.code, 3)
                    stderr = mock_stderr.getvalue()
                    self.assertIn("task name collision", stderr)

    def test_parse_scalar(self):
        """Test _parse_scalar for common scalar values and JSON fallbacks."""
        # Empty/Whitespace
        self.assertEqual(profile_parser._parse_scalar(""), "")
        self.assertEqual(profile_parser._parse_scalar("  "), "")

        # Booleans (True)
        self.assertTrue(profile_parser._parse_scalar("true"))
        self.assertTrue(profile_parser._parse_scalar("True"))
        self.assertTrue(profile_parser._parse_scalar("TRUE"))
        self.assertTrue(profile_parser._parse_scalar("yes"))
        self.assertTrue(profile_parser._parse_scalar("on"))

        # Booleans (False)
        self.assertFalse(profile_parser._parse_scalar("false"))
        self.assertFalse(profile_parser._parse_scalar("False"))
        self.assertFalse(profile_parser._parse_scalar("FALSE"))
        self.assertFalse(profile_parser._parse_scalar("no"))
        self.assertFalse(profile_parser._parse_scalar("No"))
        self.assertFalse(profile_parser._parse_scalar("off"))
        self.assertFalse(profile_parser._parse_scalar("OFF"))

        # Nulls
        self.assertIsNone(profile_parser._parse_scalar("null"))
        self.assertIsNone(profile_parser._parse_scalar("Null"))
        self.assertIsNone(profile_parser._parse_scalar("NULL"))
        self.assertIsNone(profile_parser._parse_scalar("none"))
        self.assertIsNone(profile_parser._parse_scalar("None"))
        self.assertIsNone(profile_parser._parse_scalar("NONE"))
        self.assertIsNone(profile_parser._parse_scalar("~"))

        # Numbers
        self.assertEqual(profile_parser._parse_scalar("123"), 123)
        self.assertEqual(profile_parser._parse_scalar("+123"), 123)
        self.assertEqual(profile_parser._parse_scalar("-456"), -456)
        self.assertEqual(profile_parser._parse_scalar("3.14"), 3.14)
        self.assertEqual(profile_parser._parse_scalar("1e-10"), 1e-10)

        # Non-decimal numerics (hex, oct, bin)
        self.assertEqual(profile_parser._parse_scalar("0x10"), 16)
        self.assertEqual(profile_parser._parse_scalar("-0x10"), -16)
        self.assertEqual(profile_parser._parse_scalar("+0x10"), 16)
        self.assertEqual(profile_parser._parse_scalar("0b101"), 5)
        self.assertEqual(profile_parser._parse_scalar("-0b101"), -5)
        self.assertEqual(profile_parser._parse_scalar("0o7"), 7)
        self.assertEqual(profile_parser._parse_scalar("-0o7"), -7)

        # Leading zeros (should be treated as strings)
        self.assertEqual(profile_parser._parse_scalar("0123"), "0123")
        self.assertEqual(profile_parser._parse_scalar("+0123"), "+0123")
        self.assertEqual(profile_parser._parse_scalar("-0123"), "-0123")

        # Quoted strings
        self.assertEqual(profile_parser._parse_scalar("'hello'"), "hello")
        self.assertEqual(profile_parser._parse_scalar('"world"'), "world")
        self.assertEqual(profile_parser._parse_scalar("'it''s'"), "it's")

        # Literal strings
        self.assertEqual(profile_parser._parse_scalar("hello"), "hello")
        self.assertEqual(profile_parser._parse_scalar("123-abc"), "123-abc")

        # JSON fallbacks
        # Note: These are NOT standard YAML scalars but supported via fallback.
        self.assertEqual(profile_parser._parse_scalar("[1, 2]"), [1, 2])
        self.assertEqual(profile_parser._parse_scalar('{"a": 1}'), {"a": 1})

        # Single quoted dict (should fall back to string because it's not valid JSON)
        self.assertEqual(profile_parser._parse_scalar("{'a': 1}"), "{'a': 1}")

        # Non-Python-literal flow mapping (should fall back to string)
        self.assertEqual(profile_parser._parse_scalar("{a: 1}"), "{a: 1}")

    def test_parse_scalar_dos_resilience(self):
        """Verify that _parse_scalar is resilient against deeply nested inputs (no RecursionError)."""
        # Create a deeply nested JSON-like structure.
        # Large depth should trigger RecursionError in vulnerable parsers.
        depth = 10000
        malicious_input = "[" * depth + "1" + "]" * depth

        # json.loads may have a recursion limit.
        # ast.literal_eval is known to crash with RecursionError on such inputs.
        try:
            result = profile_parser._parse_scalar(malicious_input)
            # If it didn't crash, it should either have parsed it or returned it as a string.
            if isinstance(result, list):
                # Verify depth if it actually parsed it (unlikely at 10k depth for most systems)
                curr = result
                for _ in range(depth - 1):
                    curr = curr[0]
                self.assertEqual(curr, [1])
            else:
                self.assertEqual(result, malicious_input)
        except RecursionError:
            self.fail("_parse_scalar raised RecursionError on deeply nested input")

if __name__ == '__main__':
    unittest.main()
