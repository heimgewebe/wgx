import unittest
from pathlib import Path
import tempfile
import shutil

# We can't easily import from the bash script, so we'll redefine the logic here
# to verify its correctness, or just test it as a black box if we wanted to
# wrap it in a function and import it. For now, testing the logic is key.

def get_file_info(root: Path, allowed_suffixes=None):
    if not root.exists():
        return []
    info = []
    for path in root.rglob("*"):
        if path.is_file():
            if allowed_suffixes and path.suffix.lower() not in allowed_suffixes:
                continue
            info.append((path.stem.lower(), path.name.lower()))
    return info

def count_matches(file_info, token: str):
    token_lower = token.lower()
    total = 0
    for stem, name in file_info:
        if token_lower in stem or token_lower in name:
            total += 1
    return total

class TestReadinessLogic(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_missing_root(self):
        non_existent = self.test_dir / "does_not_exist"
        info = get_file_info(non_existent)
        self.assertEqual(info, [])
        self.assertEqual(count_matches(info, "anything"), 0)

    def test_matching_logic(self):
        (self.test_dir / "test_module.bash").touch()
        (self.test_dir / "other.txt").touch()

        info = get_file_info(self.test_dir)
        # Matches stem 'test_module' or name 'test_module.bash'
        self.assertEqual(count_matches(info, "test_module"), 1)
        # Matches name 'other.txt' (contains 'other')
        self.assertEqual(count_matches(info, "other"), 1)
        # Case insensitive
        self.assertEqual(count_matches(info, "TEST_MODULE"), 1)
        # No matches
        self.assertEqual(count_matches(info, "missing"), 0)

    def test_suffix_filtering(self):
        (self.test_dir / "doc1.md").touch()
        (self.test_dir / "doc2.txt").touch()
        (self.test_dir / "image.png").touch()

        allowed = {".md", ".txt"}
        info = get_file_info(self.test_dir, allowed_suffixes=allowed)

        self.assertEqual(len(info), 2)
        self.assertEqual(count_matches(info, "doc"), 2)
        self.assertEqual(count_matches(info, "image"), 0)

    def test_nested_directories(self):
        subdir = self.test_dir / "sub"
        subdir.mkdir()
        (subdir / "nested.md").touch()

        info = get_file_info(self.test_dir)
        self.assertEqual(len(info), 1)
        self.assertEqual(count_matches(info, "nested"), 1)

if __name__ == "__main__":
    unittest.main()
