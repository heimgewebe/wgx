import unittest
import tempfile
import shutil
import os
import json
from guards._util import load_data

class TestUtilLoadData(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def _write_file(self, filename, content):
        path = os.path.join(self.test_dir, filename)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return path

    def test_json_object(self):
        path = self._write_file("test.json", '{"a": 1}')
        self.assertEqual(load_data(path), [{"a": 1}])

    def test_json_array(self):
        path = self._write_file("test.json", '[{"a": 1}, {"b": 2}]')
        self.assertEqual(load_data(path), [{"a": 1}, {"b": 2}])

    def test_jsonl(self):
        path = self._write_file("test.jsonl", '{"a": 1}\n{"b": 2}')
        self.assertEqual(load_data(path), [{"a": 1}, {"b": 2}])

    def test_jsonl_with_empty_lines(self):
        path = self._write_file("test.jsonl", '{"a": 1}\n\n  \n{"b": 2}\n')
        self.assertEqual(load_data(path), [{"a": 1}, {"b": 2}])

    def test_empty_file(self):
        path = self._write_file("empty.txt", "")
        self.assertEqual(load_data(path), [])

    def test_whitespace_file(self):
        path = self._write_file("ws.txt", "  \n \t ")
        self.assertEqual(load_data(path), [])

    def test_primitive_value(self):
        path = self._write_file("prim.json", "123")
        with self.assertRaisesRegex(ValueError, "got primitive value"):
            load_data(path)

    def test_invalid_jsonl_line(self):
        path = self._write_file("invalid.jsonl", '{"a": 1}\n{invalid}\n')
        with self.assertRaisesRegex(ValueError, r"Line 2: invalid JSON:"):
            load_data(path)

if __name__ == "__main__":
    unittest.main()
