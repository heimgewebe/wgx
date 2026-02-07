import unittest
from unittest.mock import patch, mock_open, MagicMock
import os
import json
import pathlib

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
        """
        This asserts that schema parsing/validator init is cached across flows sharing the same resolved schema path.
        """
        # Goal: Verify that when two flows use the same schema, the schema is loaded only once.
        schema_path = ".wgx/contracts/shared_schema.json"

        # Setup: 2 flows, same schema, distinct data
        # Allow both relative and absolute paths for robustness against implementation changes
        base_paths = [".wgx/flows.json", schema_path, "data1.json", "data2.json"]
        allowed_paths = set(base_paths)
        for p in base_paths:
            allowed_paths.add(str(pathlib.Path(p).resolve()))

        mock_exists.side_effect = lambda p: str(p) in allowed_paths
        mock_glob.return_value = [] # No glob expansion needed

        # Calculate expected absolute path for schema to ensure precise matching
        expected_schema_abs = str(pathlib.Path(schema_path).resolve())

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
            # Use exact match for schema to verify code uses absolute path as intended
            elif s_file == expected_schema_abs:
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
        # Use exact absolute path matching for precision
        schema_open_calls = [
            str(args[0])
            for args, kwargs in mock_file.call_args_list
            if str(args[0]) == expected_schema_abs
        ]

        self.assertEqual(
            len(schema_open_calls),
            1,
            f"Expected schema to be opened exactly once (at {expected_schema_abs}), but was opened {len(schema_open_calls)} times: {schema_open_calls}"
        )

        # 2. Validator class/factory should be accessed exactly once
        self.assertEqual(mock_jsonschema.validators.validator_for.call_count, 1,
                         f"Expected validator_for to be called exactly once, but was {mock_jsonschema.validators.validator_for.call_count}")

        # Validator class instantiation check
        self.assertEqual(mock_validator_cls.call_count, 1,
                        f"Expected validator class to be instantiated exactly once, but was {mock_validator_cls.call_count}")

        # 3. Validation should happen twice (once for d1, once for d2)
        # Since we use the same validator instance (cached), we check calls on it.
        self.assertEqual(mock_validator_instance.validate.call_count, 2, "Expected validate to be called twice (once per flow)")

        # Verify it validated both items
        calls = mock_validator_instance.validate.mock_calls
        args_list = [c[1][0] for c in calls]
        self.assertIn({"id": "d1", "val": "one"}, args_list)
        self.assertIn({"id": "d2", "val": "two"}, args_list)

    @patch('guards.data_flow_guard.load_data')
    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_data_caching(self, mock_file, mock_glob, mock_exists, mock_jsonschema, mock_load_data):
        """
        Verify that data file parsing is cached across flows sharing the same data file.
        Mocks load_data directly to be robust against file system details.
        """
        schema_path = ".wgx/contracts/schema.json"
        data_path = "shared_data.json"

        # Allow both relative and absolute paths
        base_paths = [".wgx/flows.json", schema_path, data_path]
        allowed_paths = set(base_paths)
        for p in base_paths:
            allowed_paths.add(str(pathlib.Path(p).resolve()))

        mock_exists.side_effect = lambda p: str(p) in allowed_paths
        mock_glob.return_value = []

        config_content = json.dumps([
            {
                "name": "flow1",
                "schema_path": schema_path,
                "data_pattern": [data_path]
            },
            {
                "name": "flow2",
                "schema_path": schema_path,
                "data_pattern": [data_path]
            }
        ])

        schema_content = '{"type": "object"}'

        # Mock load_data to return a predictable list
        mock_load_data.return_value = [{"id": "d1", "val": "one"}]

        def open_side_effect(file, mode='r', encoding='utf-8'):
            s_file = str(file)
            if ".wgx/flows.json" in s_file:
                return mock_open(read_data=config_content).return_value
            elif schema_path in s_file:
                return mock_open(read_data=schema_content).return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)
        mock_jsonschema.RefResolver = MagicMock()

        # Run main with explicit cache size to ensure test stability
        with patch.dict(os.environ, {"DATA_FLOW_GUARD_DATA_CACHE_MAX": "256"}):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # load_data should be called exactly once despite 2 flows
        self.assertEqual(mock_load_data.call_count, 1,
                         f"Expected load_data to be called once, but was called {mock_load_data.call_count} times")

        # Validation should happen twice (once per flow)
        # 1 item per file * 2 flows = 2 validations
        self.assertEqual(mock_validator_instance.validate.call_count, 2)

    @patch('guards.data_flow_guard.load_data')
    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_data_cache_eviction(self, mock_file, mock_glob, mock_exists, mock_jsonschema, mock_load_data):
        """
        Verify that LRU eviction works (max cache size = 1).
        Load flow1 (data A) -> Cache: [A]
        Load flow2 (data B) -> Cache: [B] (A evicted)
        Load flow3 (data A) -> Cache: [A] (B evicted, A reloaded)
        """
        schema_path = "schema.json"
        data_a = "data_a.json"
        data_b = "data_b.json"

        mock_glob.return_value = []

        # Stricter path checking
        allowed_files = {schema_path, data_a, data_b, ".wgx/flows.json"}
        allowed_resolved = {str(pathlib.Path(p).resolve()) for p in allowed_files}

        def exists_side_effect(p):
            sp = str(p)
            return sp in allowed_files or sp in allowed_resolved

        mock_exists.side_effect = exists_side_effect

        config_content = json.dumps([
            {"name": "flow1", "schema_path": schema_path, "data_pattern": [data_a]},
            {"name": "flow2", "schema_path": schema_path, "data_pattern": [data_b]},
            {"name": "flow3", "schema_path": schema_path, "data_pattern": [data_a]}
        ])

        # Setup mock file system
        def open_side_effect(file, mode='r', encoding='utf-8'):
            s_file = str(file)
            if ".wgx/flows.json" in s_file:
                return mock_open(read_data=config_content).return_value
            elif schema_path in s_file:
                return mock_open(read_data='{"type":"object"}').return_value
            return mock_open(read_data="").return_value # data content handled by load_data mock

        mock_file.side_effect = open_side_effect

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)

        # Mock load_data to return simple items
        mock_load_data.return_value = [{"id": "x"}]

        # Run with Cache Max = 1
        with patch.dict(os.environ, {"DATA_FLOW_GUARD_DATA_CACHE_MAX": "1"}):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # Expected load_data calls:
        # 1. data_a (miss) -> cache [data_a]
        # 2. data_b (miss) -> eviction -> cache [data_b]
        # 3. data_a (miss because evicted) -> eviction -> cache [data_a]
        # Total: 3 calls
        self.assertEqual(mock_load_data.call_count, 3,
                         f"Expected load_data to be called 3 times due to eviction, but called {mock_load_data.call_count}")

    @patch('guards.data_flow_guard.load_data')
    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_data_cache_disabled(self, mock_file, mock_glob, mock_exists, mock_jsonschema, mock_load_data):
        """
        Verify that setting DATA_FLOW_GUARD_DATA_CACHE_MAX=0 disables caching.
        """
        schema_path = "schema.json"
        data_path = "shared_data.json"

        mock_glob.return_value = []
        # Allow paths
        mock_exists.side_effect = lambda p: True

        config_content = json.dumps([
            {"name": "flow1", "schema_path": schema_path, "data_pattern": [data_path]},
            {"name": "flow2", "schema_path": schema_path, "data_pattern": [data_path]}
        ])

        def open_side_effect(file, mode='r', encoding='utf-8'):
            if ".wgx/flows.json" in str(file):
                return mock_open(read_data=config_content).return_value
            elif schema_path in str(file):
                return mock_open(read_data='{"type":"object"}').return_value
            return mock_open(read_data="").return_value

        mock_file.side_effect = open_side_effect
        mock_load_data.return_value = [{"id": "x"}]

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)

        # Run with Cache Disabled
        with patch.dict(os.environ, {"DATA_FLOW_GUARD_DATA_CACHE_MAX": "0"}):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # load_data should be called twice (once per flow) because caching is disabled
        self.assertEqual(mock_load_data.call_count, 2,
                         f"Expected load_data to be called 2 times (caching disabled), but called {mock_load_data.call_count}")

    @patch('guards.data_flow_guard.create_retriever')
    @patch('guards.data_flow_guard.DRAFT202012', MagicMock())
    @patch('guards.data_flow_guard.HAS_REFERENCING', True)
    @patch('guards.data_flow_guard.Registry')
    @patch('guards.data_flow_guard.Resource')
    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_referencing_path(self, mock_file, mock_glob, mock_exists, mock_jsonschema, mock_resource, mock_registry, mock_create_retriever):
        # Setup: Config exists at .wgx/flows.json
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", "schema.json", "data.json"]
        mock_glob.return_value = []

        config_content = json.dumps([
            {
                "name": "ref_flow",
                "schema_path": "schema.json",
                "data_pattern": ["data.json"]
            }
        ])

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': \
            mock_open(read_data=config_content).return_value if "flows.json" in str(f) else \
            mock_open(read_data='{"type":"object"}').return_value if "schema.json" in str(f) else \
            mock_open(read_data='[{"id":"1"}]').return_value

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)

        # Mock the retriever factory
        mock_retriever_func = MagicMock()
        mock_create_retriever.return_value = mock_retriever_func

        # Verify Registry is used
        mock_registry_instance = MagicMock()
        mock_registry.return_value = mock_registry_instance
        mock_registry_instance.with_resource.return_value = mock_registry_instance # Chaining

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # Verify Resource creation
        mock_resource.from_contents.assert_called()

        # Verify create_retriever called with expected roots
        mock_create_retriever.assert_called()
        # Verify Registry usage: must be called with the function returned by create_retriever
        mock_registry.assert_called()
        args, kwargs = mock_registry.call_args
        self.assertIn('retrieve', kwargs)
        self.assertEqual(kwargs['retrieve'], mock_retriever_func)
        mock_registry_instance.with_resource.assert_called()

        # Verify validator initialized with registry
        mock_jsonschema.validators.validator_for.return_value.assert_called_with(
            unittest.mock.ANY,
            registry=mock_registry_instance
        )

        # Verify validation called
        mock_validator_instance.validate.assert_called()

    @patch('guards.data_flow_guard.HAS_REFERENCING', False)
    @patch('guards.data_flow_guard.jsonschema')
    @patch('guards.data_flow_guard.os.path.exists')
    @patch('guards.data_flow_guard.glob.glob')
    @patch('builtins.open', new_callable=mock_open)
    def test_main_legacy_fallback(self, mock_file, mock_glob, mock_exists, mock_jsonschema):
        # Setup: same as above
        mock_exists.side_effect = lambda p: p in [".wgx/flows.json", "schema.json", "data.json"]
        mock_glob.return_value = []

        config_content = json.dumps([
            {
                "name": "legacy_flow",
                "schema_path": "schema.json",
                "data_pattern": ["data.json"]
            }
        ])

        mock_file.side_effect = lambda f, m='r', encoding='utf-8': \
            mock_open(read_data=config_content).return_value if "flows.json" in str(f) else \
            mock_open(read_data='{"type":"object"}').return_value if "schema.json" in str(f) else \
            mock_open(read_data='[{"id":"1"}]').return_value

        mock_validator_instance = MagicMock()
        mock_jsonschema.validators.validator_for.return_value = MagicMock(return_value=mock_validator_instance)
        mock_jsonschema.RefResolver = MagicMock()

        with patch('guards.data_flow_guard.yaml', None):
            ret = data_flow_guard.main()

        self.assertEqual(ret, 0)

        # Verify RefResolver used
        mock_jsonschema.RefResolver.assert_called()

    @patch('guards.data_flow_guard.DRAFT202012', MagicMock())
    @patch('guards.data_flow_guard.HAS_REFERENCING', True)
    def test_create_retriever_jail_security(self):
        """Verify that the retriever enforces root jail, network restrictions, and correct base_dir usage."""
        from guards.data_flow_guard import create_retriever
        import tempfile
        import shutil

        # Helper exception that accepts kwargs (like ref=...) to match Unresolvable's signature
        class DummyUnresolvable(Exception):
            def __init__(self, *args, **kwargs):
                super().__init__(*args)

        with patch('guards.data_flow_guard.Unresolvable', DummyUnresolvable):
            # Create a temporary directory structure
            # /tmp/jail_root/safe.json
            # /tmp/outside.json
            with tempfile.TemporaryDirectory() as tmp_dir:
                # Use realpath for jail_root to avoid /tmp symlink issues on some OSes (e.g. macOS /var -> /private/var)
                # This ensures the test environment matches the realpath logic in create_retriever
                jail_root = os.path.realpath(os.path.join(tmp_dir, "jail_root"))
                os.makedirs(jail_root)

                safe_file = os.path.join(jail_root, "safe.json")
                with open(safe_file, "w") as f:
                    f.write('{"foo": "bar"}')

                unsafe_file = os.path.join(tmp_dir, "outside.json")
                with open(unsafe_file, "w") as f:
                    f.write('{"unsafe": true}')

                # Create retriever restricted to jail_root, with jail_root as base_dir
                retrieve = create_retriever(base_dir=jail_root, allowed_roots=[jail_root])

                # 1. Allowed access (Absolute path inside jail)
                safe_uri = pathlib.Path(safe_file).as_uri()
                with patch('guards.data_flow_guard.Resource') as mock_resource:
                     retrieve(safe_uri)
                     mock_resource.from_contents.assert_called()

                # 2. Allowed access (Relative path, resolved against base_dir)
                # Using just "safe.json" (scheme "") should resolve to jail_root/safe.json
                with patch('guards.data_flow_guard.Resource') as mock_resource:
                    retrieve("safe.json")
                    mock_resource.from_contents.assert_called()

                # 3. Denied access (Path Traversal / Outside Root)
                unsafe_uri = pathlib.Path(unsafe_file).as_uri()
                with self.assertRaises(DummyUnresolvable):
                    retrieve(unsafe_uri)

                # 4. Denied access (Relative path traversal escaping jail)
                # "../outside.json" relative to jail_root
                with self.assertRaises(DummyUnresolvable):
                    retrieve("../outside.json")

                # 5. Network forbidden
                with self.assertRaises(ValueError) as cm:
                    retrieve("http://example.com/schema.json")
                self.assertIn("Network/Unsupported reference forbidden", str(cm.exception))

                with self.assertRaises(ValueError) as cm:
                    retrieve("file://hostname/share/schema.json")
                self.assertIn("Network reference (UNC/remote) forbidden", str(cm.exception))

                # 6. Symlink Escape (if supported)
                if hasattr(os, "symlink"):
                    try:
                        symlink_path = os.path.join(jail_root, "link_to_outside.json")
                        os.symlink(unsafe_file, symlink_path)

                        # Try accessing the symlink (which resides inside jail, but points outside)
                        # Should be denied because we use realpath() in jail check
                        symlink_uri = pathlib.Path(symlink_path).as_uri()
                        with self.assertRaises(DummyUnresolvable):
                            retrieve(symlink_uri)
                    except OSError:
                        # Symlinks might fail on some platforms/permissions (e.g. Windows without dev mode)
                        pass

if __name__ == '__main__':
    unittest.main()
