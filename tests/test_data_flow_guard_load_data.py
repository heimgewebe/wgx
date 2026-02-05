import unittest
import json
import tempfile
import shutil
import os
import sys

# Ensure imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from guards import data_flow_guard

class TestLoadData(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def _write_file(self, filename, content):
        path = os.path.join(self.test_dir, filename)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return path

    def test_valid_json_object(self):
        path = self._write_file("obj.json", '{"id": "123", "val": "abc"}')
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [{"id": "123", "val": "abc"}])

    def test_valid_json_array(self):
        path = self._write_file("arr.json", '[{"id": "1"}, {"id": "2"}]')
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [{"id": "1"}, {"id": "2"}])

    def test_valid_jsonl(self):
        content = '{"id": "1"}\n{"id": "2"}'
        path = self._write_file("data.jsonl", content)
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [{"id": "1"}, {"id": "2"}])

    def test_valid_jsonl_with_empty_lines(self):
        content = '{"id": "1"}\n\n   \n{"id": "2"}\n'
        path = self._write_file("data_gaps.jsonl", content)
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [{"id": "1"}, {"id": "2"}])

    def test_empty_file(self):
        path = self._write_file("empty.json", "")
        # Expect empty list (treated as empty JSONL)
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [])

    def test_whitespace_file(self):
        path = self._write_file("ws.json", "   \n  \t ")
        data = data_flow_guard.load_data(path)
        self.assertEqual(data, [])

    def test_invalid_json_garbage(self):
        path = self._write_file("garbage.json", "this is garbage")
        with self.assertRaises(ValueError) as cm:
            data_flow_guard.load_data(path)
        msg = str(cm.exception)
        self.assertIn("Line 1", msg)
        self.assertIn("invalid JSON", msg)

    def test_mixed_valid_invalid_jsonl(self):
        content = '{"id": "1"}\nGARBAGE\n{"id": "2"}'
        path = self._write_file("mixed.jsonl", content)
        with self.assertRaises(ValueError) as cm:
            data_flow_guard.load_data(path)
        msg = str(cm.exception)
        self.assertIn("Line 2", msg)
        self.assertIn("invalid JSON", msg)

    def test_json_primitive(self):
        # A primitive like "123" or "true" is valid JSON but we enforce Object or Array
        path = self._write_file("prim.json", "123")
        with self.assertRaises(ValueError) as cm:
            data_flow_guard.load_data(path)
        self.assertIn("File content must be a JSON object or array", str(cm.exception))

if __name__ == '__main__':
    unittest.main()
