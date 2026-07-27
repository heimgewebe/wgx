#!/usr/bin/env python3

import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from modules import profile_parser
from scripts import validate_operator_capabilities as validator


ROOT = Path(__file__).resolve().parent.parent


class OperatorCapabilitiesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.payload = json.loads((ROOT / validator.DEFAULT_MAP).read_text(encoding="utf-8"))

    def validate(self, payload: object) -> list[str]:
        return validator.validate(payload, ROOT)

    def test_repository_inventory_is_valid(self) -> None:
        self.assertEqual(self.validate(self.payload), [])

    def test_consumer_requires_evidence_path(self) -> None:
        payload = copy.deepcopy(self.payload)
        del payload["capabilities"][0]["consumers"][0]["evidence_path"]
        findings = self.validate(payload)
        self.assertTrue(any("evidence_path is required" in item for item in findings))

    def test_consumer_url_must_match_repository_and_path(self) -> None:
        payload = copy.deepcopy(self.payload)
        consumer = payload["capabilities"][0]["consumers"][0]
        consumer["source_url"] = (
            "https://github.com/heimgewebe/wgx/blob/"
            "c4b41809664353a3cff310dd4d6ef4d75be2ff60/"
            ".github/workflows/wgx-guard.yml"
        )
        findings = self.validate(payload)
        self.assertTrue(
            any("source_url must link repository/evidence_path exactly" in item for item in findings)
        )

    def test_consumer_requires_repository_native_alternative(self) -> None:
        payload = copy.deepcopy(self.payload)
        del payload["capabilities"][0]["consumers"][0]["repository_native_alternative"]
        findings = self.validate(payload)
        self.assertTrue(any("repository_native_alternative is required" in item for item in findings))

    def test_authority_owner_must_not_be_empty(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["authority_boundary"]["owners"]["bureau_task_coordination"]["owner"] = " "
        findings = self.validate(payload)
        self.assertTrue(any("bureau_task_coordination.owner is required" in item for item in findings))

    def test_authority_contradiction_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["authority_boundary"]["owners"]["bureau_task_coordination"]["owner"] = (
            "heimgewebe/wgx"
        )
        findings = self.validate(payload)
        self.assertTrue(
            any("WGX cannot own bureau_task_coordination" in item for item in findings)
        )

    def test_broad_no_host_mutation_overclaim_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["authority_boundary"]["does_not_own"][-1] = "generic_host_mutation"
        findings = self.validate(payload)
        self.assertTrue(any("does_not_own must contain exactly" in item for item in findings))

    def test_removed_required_capability_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"] = [
            item
            for item in payload["capabilities"]
            if item["id"] != "metrics-contract-compatibility"
        ]
        findings = self.validate(payload)
        self.assertTrue(
            any("required retained capability IDs are missing" in item for item in findings)
        )

    def test_duplicate_capability_id_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][1]["id"] = payload["capabilities"][0]["id"]
        findings = self.validate(payload)
        self.assertTrue(any("duplicate capability id" in item for item in findings))

    def test_missing_local_evidence_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["local_evidence_paths"] = ["tests/does-not-exist.bats"]
        findings = self.validate(payload)
        self.assertTrue(any("local_evidence_paths path is missing" in item for item in findings))

    def test_invalid_replacement_owner_and_path_are_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        template = next(
            item
            for item in payload["capabilities"]
            if item["id"] == "wgx-profile-starter-templates"
        )
        template["disposition"] = "retired_replaced"
        template["surfaces"] = ["templates/retired-does-not-exist.yml"]
        template["replacement"] = {
            "owner": "",
            "path": "",
            "source_url": "invalid",
            "distribution_url": "invalid",
            "ci_coverage_url": "invalid",
            "local_coverage_paths": ["tests/test_operator_capabilities.py"],
        }
        findings = self.validate(payload)
        self.assertTrue(any("replacement.owner is required" in item for item in findings))
        self.assertTrue(any("replacement.path is required" in item for item in findings))
        self.assertTrue(any("replacement.source_url must be source-linked" in item for item in findings))

    def test_missing_operational_command_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["operational_commands"] = [
            item for item in payload["operational_commands"] if item["id"] != "reload"
        ]
        findings = self.validate(payload)
        self.assertTrue(any("operational command inventory is missing: reload" in item for item in findings))

    def test_delegated_execution_must_disclose_host_effects(self) -> None:
        payload = copy.deepcopy(self.payload)
        command = next(item for item in payload["operational_commands"] if item["id"] == "run")
        command["effects"] = "Runs a safe repository task."
        findings = self.validate(payload)
        self.assertTrue(any("must disclose unconfined host effects" in item for item in findings))

    def test_missing_workflow_trigger_coverage_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        incomplete = {
            "pull_request": ["docs/operator-ecosystem-capabilities.v1.json"],
            "push": ["docs/operator-ecosystem-capabilities.v1.json"],
        }
        with patch.object(validator, "_workflow_patterns", return_value=incomplete):
            findings = self.validate(payload)
        self.assertTrue(
            any(
                "workflow pull_request trigger misses required path: cmd/clean.bash" in item
                for item in findings
            )
        )

    def test_restored_executable_templates_keep_tasks(self) -> None:
        expected_tasks = {
            "templates/.wgx/profile.yml": {"integrity", "test", "lint"},
            "templates/profile.template.yml": {"doctor", "test"},
            "templates/profiles/docs-only.yml": {"smoke", "guard", "metrics", "snapshot"},
            "templates/profiles/meta.yml": {"smoke", "guard", "metrics", "snapshot"},
            "templates/profiles/python-service.yml": {"smoke", "guard", "metrics", "snapshot"},
            "templates/profiles/rust-service.yml": {"smoke", "guard", "metrics", "snapshot"},
        }
        for relative_path, names in expected_tasks.items():
            with self.subTest(profile=relative_path):
                profile = profile_parser._load_manifest(str(ROOT / relative_path))
                tasks = profile.get("wgx", {}).get("tasks", profile.get("tasks", {}))
                self.assertIsInstance(tasks, dict)
                self.assertTrue(names.issubset(tasks))


if __name__ == "__main__":
    unittest.main()
