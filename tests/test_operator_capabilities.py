#!/usr/bin/env python3

import copy
import hashlib
import json
import os
import tempfile
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
        cls.evidence = json.loads(
            (ROOT / validator.PINNED_EVIDENCE_PATH).read_text(encoding="utf-8")
        )

    def validate(self, payload: object) -> list[str]:
        return validator.validate(payload, ROOT)

    def load_evidence(
        self, evidence: object
    ) -> tuple[dict[str, dict[str, object]], list[str]]:
        findings: list[str] = []
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            evidence_path = root / validator.PINNED_EVIDENCE_PATH
            evidence_path.parent.mkdir(parents=True)
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            records = validator._load_pinned_evidence(root, findings)
        return records, findings

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
        self.assertTrue(
            any("local_evidence_paths[0] path is missing" in item for item in findings)
        )

    def test_absolute_local_path_is_rejected_even_when_file_exists(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["local_evidence_paths"] = ["/etc/hosts"]
        findings = self.validate(payload)
        self.assertTrue(
            any("repository-relative without parent traversal" in item for item in findings)
        )

    def test_parent_escape_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["local_evidence_paths"] = ["../etc/hosts"]
        findings = self.validate(payload)
        self.assertTrue(
            any("repository-relative without parent traversal" in item for item in findings)
        )

    def test_symlink_escape_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["local_evidence_paths"] = ["escape/hosts"]
        with tempfile.TemporaryDirectory() as temporary_root:
            os.symlink("/etc", Path(temporary_root) / "escape")
            findings = validator.validate(payload, Path(temporary_root))
        self.assertTrue(any("must not contain symlinks" in item for item in findings))

    def test_internal_symlink_is_rejected(self) -> None:
        findings: list[str] = []
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            target = root / "target"
            target.mkdir()
            (target / "evidence.txt").write_text("evidence\n", encoding="utf-8")
            os.symlink("target", root / "internal-link")
            resolved = validator._safe_local_path(
                "internal-link/evidence.txt",
                root,
                "internal evidence",
                findings,
            )
        self.assertIsNone(resolved)
        self.assertTrue(any("must not contain symlinks" in item for item in findings))

    def test_ordinary_repository_relative_path_is_preserved(self) -> None:
        findings: list[str] = []
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            expected = root / "docs" / "evidence.txt"
            expected.parent.mkdir()
            expected.write_text("evidence\n", encoding="utf-8")
            resolved = validator._safe_local_path(
                "docs/evidence.txt",
                root,
                "ordinary evidence",
                findings,
            )
            self.assertEqual(resolved, expected)
        self.assertEqual(findings, [])

    def test_unrelated_alternative_owner_url_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        alternative = payload["capabilities"][0]["consumers"][0][
            "repository_native_alternative"
        ]
        alternative["owner"] = "heimgewebe/chronik"
        alternative["source_url"] = (
            "https://github.com/heimgewebe/chronik/blob/"
            "0596f6624e2bab3de81f8b0a32a1dbf45a0e1482/"
            ".github/workflows/tests.yml"
        )
        findings = self.validate(payload)
        self.assertTrue(
            any("must equal expected repository" in item for item in findings)
        )
        self.assertTrue(
            any("must link expected owner/repository/path" in item for item in findings)
        )

    def test_nonexistent_canonical_invocation_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["consumers"][0][
            "canonical_invocation"
        ] = "uses: heimgewebe/wgx/.github/workflows/does-not-exist.yml@main"
        findings = self.validate(payload)
        self.assertTrue(
            any("canonical_invocation is not evidenced" in item for item in findings)
        )

    def test_invocation_and_excerpt_hash_cannot_forge_blob_evidence(self) -> None:
        payload = copy.deepcopy(self.payload)
        evidence = copy.deepcopy(self.evidence)
        consumer = payload["capabilities"][0]["consumers"][0]
        original = consumer["canonical_invocation"]
        forged = (
            "uses: heimgewebe/wgx/.github/workflows/forged-guard.yml@main"
        )
        consumer["canonical_invocation"] = forged
        record = next(
            item
            for item in evidence["sources"]
            if item["source_url"] == consumer["source_url"]
        )
        record["blob_content"] = record["blob_content"].replace(original, forged)
        record["content_sha256"] = hashlib.sha256(
            record["blob_content"].encode("utf-8")
        ).hexdigest()

        records, findings = self.load_evidence(evidence)
        with patch.object(validator, "_load_pinned_evidence", return_value=records):
            validation_findings = self.validate(payload)

        self.assertNotIn(consumer["source_url"], records)
        self.assertTrue(
            any("blob_sha does not match the complete Git blob content" in item for item in findings)
        )
        self.assertTrue(
            any(
                "source_url has no checked-in pinned source evidence" in item
                for item in validation_findings
            )
        )

    def test_altered_blob_content_is_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"][0]["blob_content"] += "# forged\n"

        _, findings = self.load_evidence(evidence)

        self.assertTrue(any("content_sha256 does not match" in item for item in findings))
        self.assertTrue(
            any("blob_sha does not match the complete Git blob content" in item for item in findings)
        )

    def test_altered_blob_id_is_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"][0]["blob_sha"] = "0" * 40

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any("blob_sha does not match the complete Git blob content" in item for item in findings)
        )

    def test_source_evidence_url_path_and_commit_must_match_record(self) -> None:
        for component, replacement in (
            ("repository", "heimgewebe/forged"),
            ("path", ".github/workflows/forged.yml"),
            ("commit", "0" * 40),
        ):
            with self.subTest(component=component):
                evidence = copy.deepcopy(self.evidence)
                record = evidence["sources"][0]
                if component == "repository":
                    record["repository"] = replacement
                elif component == "path":
                    record["source_url"] = record["source_url"].replace(
                        record["path"], replacement
                    )
                else:
                    record["source_url"] = record["source_url"].replace(
                        record["commit_sha"], replacement
                    )

                _, findings = self.load_evidence(evidence)

                self.assertTrue(
                    any(
                        "URL/repository/path/commit binding is invalid" in item
                        for item in findings
                    )
                )

    def test_duplicate_source_evidence_record_is_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"].append(copy.deepcopy(evidence["sources"][0]))

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any("duplicate pinned source evidence URL" in item for item in findings)
        )

    def test_partial_invocation_prose_is_not_accepted_as_evidence(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["consumers"][0]["canonical_invocation"] = "uses:"
        findings = self.validate(payload)
        self.assertTrue(
            any("canonical_invocation is not evidenced" in item for item in findings)
        )

    def test_historical_wgx_url_requires_checked_in_source_content(self) -> None:
        with patch.object(validator, "_load_pinned_evidence", return_value={}):
            findings = self.validate(self.payload)
        self.assertTrue(
            any("historical c4b4180 WGX source URL lacks" in item for item in findings)
        )

    def test_swapped_category_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["category"] = "metrics"
        findings = self.validate(payload)
        self.assertTrue(any("category must be guard" in item for item in findings))

    def test_explicit_authority_contradiction_in_capability_prose_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["capabilities"][0]["summary"] = (
            "WGX owns and coordinates Bureau task execution."
        )
        findings = self.validate(payload)
        self.assertTrue(
            any("authority contradiction in prose" in item for item in findings)
        )

    def test_missing_required_surface_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        integrity = next(
            item
            for item in payload["capabilities"]
            if item["id"] == "scheduled-integrity-publication"
        )
        integrity["surfaces"].remove(".github/workflows/wgx-integrity.yml")
        findings = self.validate(payload)
        self.assertTrue(any("required surfaces are missing" in item for item in findings))

    def test_sync_remote_alias_classification_is_fail_closed(self) -> None:
        payload = copy.deepcopy(self.payload)
        command = next(
            item for item in payload["operational_commands"] if item["id"] == "sync-remote"
        )
        command["classification"] = "unavailable"
        command["delegates_to"] = []
        findings = self.validate(payload)
        self.assertTrue(
            any(
                "classification must be repository_scoped_destructive_mutation" in item
                for item in findings
            )
        )
        self.assertTrue(any("delegates_to must equal ['reload']" in item for item in findings))

    def test_metrics_base_behaviors_are_retained(self) -> None:
        workflow = (ROOT / ".github/workflows/metrics.yml").read_text(encoding="utf-8")
        for required in (
            'cron: "0 * * * *"',
            "HAUSKI_POST_URL: ${{ secrets.HAUSKI_METRICS_URL }}",
            "Optional POST to hausKI",
            "uses: actions/upload-artifact@v4",
            "retention-days: 7",
        ):
            with self.subTest(required=required):
                self.assertIn(required, workflow)
        self.assertNotIn("actions: write", workflow)
        self.assertNotIn("checks: write", workflow)

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
