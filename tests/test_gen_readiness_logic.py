import unittest
import json
import subprocess
import shutil
import tempfile
import os
from pathlib import Path

class TestGenReadinessBlackbox(unittest.TestCase):
    def setUp(self):
        self.tmp_repo = Path(tempfile.mkdtemp())
        self.real_script_path = Path(__file__).resolve().parent.parent / "scripts" / "gen-readiness.sh"
        # Ensure we have a script to run
        if not self.real_script_path.exists():
            raise FileNotFoundError(f"Script not found at {self.real_script_path}")

        # Copy script to tmp_repo to ensure it finds the correct REPO_DIR via BASH_SOURCE
        self.script_dir = self.tmp_repo / "scripts"
        self.script_dir.mkdir()
        self.script_path = self.script_dir / "gen-readiness.sh"
        shutil.copy(self.real_script_path, self.script_path)
        self.script_path.chmod(0o755)

    def tearDown(self):
        shutil.rmtree(self.tmp_repo)

    def run_script(self):
        # We need to ensure python3 is in PATH
        env = os.environ.copy()
        result = subprocess.run(
            [str(self.script_path)],
            cwd=self.tmp_repo,
            capture_output=True,
            text=True,
            env=env
        )
        if result.returncode != 0:
            print(f"STDOUT: {result.stdout}")
            print(f"STDERR: {result.stderr}")
        return result

    def create_structure(self, modules=None, cmd=None, tests=None, docs=None):
        if modules:
            m_dir = self.tmp_repo / "modules"
            m_dir.mkdir(parents=True, exist_ok=True)
            for m in modules:
                (m_dir / f"{m}.bash").touch()
        if cmd:
            c_dir = self.tmp_repo / "cmd"
            c_dir.mkdir(parents=True, exist_ok=True)
            for c in cmd:
                (c_dir / f"{c}.bash").touch()
        if tests:
            t_dir = self.tmp_repo / "tests"
            t_dir.mkdir(parents=True, exist_ok=True)
            for t_path in tests:
                path = t_dir / t_path
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
        if docs:
            d_dir = self.tmp_repo / "docs"
            d_dir.mkdir(parents=True, exist_ok=True)
            for d_path in docs:
                path = d_dir / d_path
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()

    def get_readiness_data(self):
        readiness_json = self.tmp_repo / "artifacts" / "readiness.json"
        if not readiness_json.exists():
            return None
        return json.loads(readiness_json.read_text())

    def test_full_readiness(self):
        # Module 'foo' has everything: modules/, cmd/, tests/, and docs/
        self.create_structure(
            modules=["foo"],
            cmd=["foo"],
            tests=["test_foo.py"],
            docs=["foo.md"]
        )

        res = self.run_script()
        self.assertEqual(res.returncode, 0, f"Script failed: {res.stderr}")

        data = self.get_readiness_data()
        self.assertIsNotNone(data)

        foo_entry = next((m for m in data["modules"] if m["module"] == "foo"), None)
        self.assertIsNotNone(foo_entry)
        self.assertEqual(foo_entry["status"], "ready")
        self.assertEqual(foo_entry["coverage"], 100)
        self.assertEqual(foo_entry["tests"], 1)
        self.assertEqual(foo_entry["docs"], 1)
        self.assertTrue(foo_entry["cli"])

    def test_partial_readiness(self):
        # 'bar' only has module and CLI
        # 'baz' only has module and tests
        self.create_structure(
            modules=["bar", "baz"],
            cmd=["bar"],
            tests=["test_baz.bash"]
        )

        self.run_script()
        data = self.get_readiness_data()

        bar = next(m for m in data["modules"] if m["module"] == "bar")
        # score = (1 if tests > 0 else 0) + (1 if cli else 0) + (1 if docs > 0 else 0)
        # bar: tests=0, cli=True, docs=0 -> score=1 -> status="partial"
        self.assertEqual(bar["status"], "partial")

        baz = next(m for m in data["modules"] if m["module"] == "baz")
        self.assertEqual(baz["status"], "partial") # tests=1, cli=False, docs=0 -> score=1

    def test_docs_suffix_filtering(self):
        # Only .md, .txt, .rst should be counted for docs
        self.create_structure(
            modules=["doc_test"],
            docs=["doc_test.md", "doc_test.txt", "doc_test.rst", "doc_test.png", "doc_test.json"]
        )

        self.run_script()
        data = self.get_readiness_data()

        entry = data["modules"][0]
        self.assertEqual(entry["docs"], 3) # .md, .txt, .rst

    def test_nested_files(self):
        self.create_structure(
            modules=["nested"],
            tests=["subdir/test_nested.bash"],
            docs=["deep/path/nested.md"]
        )

        self.run_script()
        data = self.get_readiness_data()

        entry = data["modules"][0]
        self.assertEqual(entry["tests"], 1)
        self.assertEqual(entry["docs"], 1)

    def test_missing_directories(self):
        # Should not crash if tests/ or docs/ are missing
        self.create_structure(modules=["minimal"])

        res = self.run_script()
        self.assertEqual(res.returncode, 0)

        data = self.get_readiness_data()
        entry = data["modules"][0]
        self.assertEqual(entry["tests"], 0)
        self.assertEqual(entry["docs"], 0)
        self.assertFalse(entry["cli"])

if __name__ == "__main__":
    unittest.main()
