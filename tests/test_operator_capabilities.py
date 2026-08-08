#!/usr/bin/env python3

import base64
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

    @staticmethod
    def trust_repository_commit(
        _repository: str, _commit_sha: str, _root_tree_sha: str
    ) -> str | None:
        return None

    def validate(self, payload: object) -> list[str]:
        return validator.validate(
            payload,
            ROOT,
            repository_commit_verifier=self.trust_repository_commit,
        )

    def load_evidence(
        self,
        evidence: object,
        repository_commit_verifier=None,
    ) -> tuple[dict[str, dict[str, object]], list[str]]:
        findings: list[str] = []
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            evidence_path = root / validator.PINNED_EVIDENCE_PATH
            evidence_path.parent.mkdir(parents=True)
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            records = validator._load_pinned_evidence(
                root,
                findings,
                repository_commit_verifier or self.trust_repository_commit,
            )
        return records, findings

    def proof(self, evidence: dict[str, object], object_id: str) -> dict[str, str]:
        return next(
            item
            for item in evidence["git_objects"]
            if item["oid"] == object_id
        )

    def parsed_objects(
        self, evidence: dict[str, object]
    ) -> dict[str, tuple[str, object]]:
        findings: list[str] = []
        objects, _object_ids = validator._load_git_object_proofs(
            evidence["git_objects"], findings
        )
        self.assertEqual(findings, [])
        return objects

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
            findings = validator.validate(
                payload,
                Path(temporary_root),
                repository_commit_verifier=self.trust_repository_commit,
            )
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

    def test_coordinated_invocation_and_complete_blob_forgery_is_rejected(
        self,
    ) -> None:
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
        record["blob_sha"] = validator._git_blob_sha(
            record["blob_content"].encode("utf-8")
        )

        records, findings = self.load_evidence(evidence)
        with patch.object(validator, "_load_pinned_evidence", return_value=records):
            validation_findings = self.validate(payload)

        self.assertNotIn(consumer["source_url"], records)
        self.assertTrue(
            any(
                "blob_sha does not match the blob mapped by commit and path" in item
                for item in findings
            )
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

    def test_non_utf8_blob_content_is_rejected_without_crashing(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"][0]["blob_content"] = "\ud800"

        _, findings = self.load_evidence(evidence)

        self.assertTrue(any("blob_content must be valid UTF-8" in item for item in findings))

    def test_altered_blob_id_is_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"][0]["blob_sha"] = "0" * 40

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any("blob_sha does not match the complete Git blob content" in item for item in findings)
        )
        self.assertTrue(
            any(
                "blob_sha does not match the blob mapped by commit and path" in item
                for item in findings
            )
        )

    def test_altered_exact_commit_object_bytes_are_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        record = evidence["sources"][0]
        proof = self.proof(evidence, record["commit_sha"])
        content = base64.b64decode(proof["content_base64"])
        proof["content_base64"] = base64.b64encode(content + b"forged\n").decode(
            "ascii"
        )

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any(
                ".oid does not match the exact commit object bytes" in item
                for item in findings
            )
        )
        self.assertTrue(
            any("commit_sha has no valid exact commit object proof" in item for item in findings)
        )

    def test_declared_root_tree_must_match_exact_commit_object(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        evidence["sources"][0]["root_tree_sha"] = "0" * 40

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any(
                "root_tree_sha does not match the exact commit object" in item
                for item in findings
            )
        )

    def test_altered_intermediate_tree_object_bytes_are_rejected(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        record = evidence["sources"][0]
        objects = self.parsed_objects(evidence)
        intermediate_tree = objects[record["root_tree_sha"]][1][b".github"][1]
        proof = self.proof(evidence, intermediate_tree)
        content = base64.b64decode(proof["content_base64"])
        proof["content_base64"] = base64.b64encode(content[:-1]).decode("ascii")

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any(
                ".oid does not match the exact tree object bytes" in item
                for item in findings
            )
        )
        self.assertTrue(
            any("has no valid exact tree object proof" in item for item in findings)
        )

    def test_path_proof_rejects_wrong_modes_and_object_types(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        record = evidence["sources"][0]
        objects = self.parsed_objects(evidence)
        root_tree = record["root_tree_sha"]
        github_tree = objects[root_tree][1][b".github"][1]
        workflows_tree = objects[github_tree][1][b"workflows"][1]

        mutations = (
            (
                "intermediate mode",
                root_tree,
                b".github",
                ("100644", github_tree),
                "must be a canonical tree entry",
            ),
            (
                "final symlink mode",
                workflows_tree,
                b"wgx-guard.yml",
                ("120000", record["blob_sha"]),
                "must be an ordinary blob entry",
            ),
        )
        for label, tree_id, component, replacement, expected in mutations:
            with self.subTest(label=label):
                altered = copy.deepcopy(objects)
                altered[tree_id][1][component] = replacement
                findings: list[str] = []
                valid, _used = validator._validate_git_path_proof(
                    record, altered, "source", findings
                )
                self.assertFalse(valid)
                self.assertTrue(any(expected in item for item in findings))

        wrong_type = copy.deepcopy(objects)
        wrong_type[github_tree] = ("commit", wrong_type[github_tree][1])
        findings = []
        valid, _used = validator._validate_git_path_proof(
            record, wrong_type, "source", findings
        )
        self.assertFalse(valid)
        self.assertTrue(any("wrong Git object type" in item for item in findings))

    def test_missing_path_component_is_rejected_by_proven_tree(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        record = evidence["sources"][0]
        record["path"] = record["path"].replace("wgx-guard.yml", "missing.yml")
        record["source_url"] = record["source_url"].replace(
            "wgx-guard.yml", "missing.yml"
        )

        _, findings = self.load_evidence(evidence)

        self.assertTrue(
            any("is missing from the proven tree" in item for item in findings)
        )

    def test_git_tree_parser_rejects_truncation_duplicates_and_bad_order(self) -> None:
        object_id = bytes.fromhex("1" * 40)
        malformed_trees = (
            b"100644 file\0" + object_id[:-1],
            b"100644 file\0" + object_id + b"100755 file\0" + object_id,
            b"100644 z\0" + object_id + b"100644 a\0" + object_id,
        )
        for content in malformed_trees:
            with self.subTest(content=content):
                with self.assertRaises(ValueError):
                    validator._parse_git_tree(content)

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

    def test_repository_commit_must_be_authenticated_against_declared_repo(self) -> None:
        evidence = copy.deepcopy(self.evidence)
        record = evidence["sources"][0]
        original_repository = record["repository"]
        record["repository"] = "heimgewebe/forged"
        record["source_url"] = record["source_url"].replace(
            original_repository, record["repository"], 1
        )

        def reject_forged_repository(
            repository: str, _commit_sha: str, _root_tree_sha: str
        ) -> str | None:
            if repository == "heimgewebe/forged":
                return "GitHub returned HTTP 404"
            return None

        records, findings = self.load_evidence(
            evidence, reject_forged_repository
        )

        self.assertNotIn(record["source_url"], records)
        self.assertTrue(
            any("is not authenticated against heimgewebe/forged" in item for item in findings)
        )

    def test_repository_commit_authentication_is_cached_per_commit(self) -> None:
        calls: list[tuple[str, str, str]] = []

        def record_call(
            repository: str, commit_sha: str, root_tree_sha: str
        ) -> str | None:
            calls.append((repository, commit_sha, root_tree_sha))
            return None

        _records, findings = self.load_evidence(self.evidence, record_call)

        expected = {
            (item["repository"], item["commit_sha"], item["root_tree_sha"])
            for item in self.evidence["sources"]
        }
        self.assertEqual(findings, [])
        self.assertEqual(set(calls), expected)
        self.assertEqual(len(calls), len(expected))

    def test_github_headers_prefer_environment_token(self) -> None:
        with patch.dict(os.environ, {"GITHUB_TOKEN": "env-token"}, clear=True):
            with patch.object(validator.subprocess, "run") as run:
                headers = validator._github_headers()

        self.assertEqual(headers["Authorization"], "Bearer env-token")
        run.assert_not_called()

    def test_github_headers_use_authenticated_gh_fallback(self) -> None:
        completed = validator.subprocess.CompletedProcess(
            args=["gh", "auth", "token"], returncode=0, stdout="gh-token\n", stderr=""
        )
        with patch.dict(os.environ, {}, clear=True):
            with patch.object(validator.subprocess, "run", return_value=completed) as run:
                headers = validator._github_headers()

        self.assertEqual(headers["Authorization"], "Bearer gh-token")
        self.assertEqual(
            run.call_args.args[0],
            ["gh", "auth", "token", "--hostname", "github.com"],
        )

    def test_github_headers_fail_closed_without_usable_token(self) -> None:
        completed = validator.subprocess.CompletedProcess(
            args=["gh", "auth", "token"], returncode=0, stdout="bad token\n", stderr=""
        )
        with patch.dict(os.environ, {}, clear=True):
            with patch.object(validator.subprocess, "run", return_value=completed):
                headers = validator._github_headers()

        self.assertNotIn("Authorization", headers)

    def test_github_commit_verifier_binds_reachable_default_branch_commit(self) -> None:
        commit_sha = "a" * 40
        root_tree_sha = "b" * 40
        object_data = {
            "repository": {
                "object": {
                    "oid": commit_sha,
                    "committedDate": "2026-07-27T20:57:31Z",
                    "tree": {"oid": root_tree_sha},
                },
                "defaultBranchRef": {"name": "main"},
            }
        }
        history_data = {
            "repository": {
                "defaultBranchRef": {
                    "target": {
                        "history": {
                            "nodes": [{"oid": commit_sha}],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }
        with patch.object(
            validator,
            "_read_github_graphql",
            side_effect=[(object_data, None), (history_data, None)],
        ) as read:
            error = validator._verify_github_repository_commit(
                "heimgewebe/wgx", commit_sha, root_tree_sha
            )

        self.assertIsNone(error)
        self.assertEqual(read.call_count, 2)
        self.assertEqual(
            read.call_args_list[0].args[1],
            {"owner": "heimgewebe", "name": "wgx", "oid": commit_sha},
        )
        self.assertEqual(
            read.call_args_list[1].args[1],
            {
                "owner": "heimgewebe",
                "name": "wgx",
                "since": "2026-07-27T20:57:31Z",
                "until": "2026-07-27T20:57:31Z",
            },
        )

    def test_github_commit_verifier_rejects_wrong_remote_tree(self) -> None:
        commit_sha = "a" * 40
        root_tree_sha = "b" * 40
        object_data = {
            "repository": {
                "object": {
                    "oid": commit_sha,
                    "committedDate": "2026-07-27T20:57:31Z",
                    "tree": {"oid": "c" * 40},
                },
                "defaultBranchRef": {"name": "main"},
            }
        }
        with patch.object(
            validator,
            "_read_github_graphql",
            return_value=(object_data, None),
        ):
            error = validator._verify_github_repository_commit(
                "heimgewebe/wgx", commit_sha, root_tree_sha
            )

        self.assertEqual(
            error, "GitHub commit response does not match the proven root tree"
        )

    def test_github_commit_verifier_rejects_fork_only_commit(self) -> None:
        commit_sha = "a" * 40
        root_tree_sha = "b" * 40
        object_data = {
            "repository": {
                "object": {
                    "oid": commit_sha,
                    "committedDate": "2026-07-27T20:57:31Z",
                    "tree": {"oid": root_tree_sha},
                },
                "defaultBranchRef": {"name": "main"},
            }
        }
        history_data = {
            "repository": {
                "defaultBranchRef": {
                    "target": {
                        "history": {
                            "nodes": [],
                            "pageInfo": {"hasNextPage": False},
                        }
                    }
                }
            }
        }
        with patch.object(
            validator,
            "_read_github_graphql",
            side_effect=[(object_data, None), (history_data, None)],
        ):
            error = validator._verify_github_repository_commit(
                "heimgewebe/wgx", commit_sha, root_tree_sha
            )

        self.assertEqual(
            error,
            "declared commit is not reachable from the repository default branch",
        )

    def test_github_commit_verifier_fails_closed_on_unbounded_timestamp(self) -> None:
        commit_sha = "a" * 40
        root_tree_sha = "b" * 40
        object_data = {
            "repository": {
                "object": {
                    "oid": commit_sha,
                    "committedDate": "2026-07-27T20:57:31Z",
                    "tree": {"oid": root_tree_sha},
                },
                "defaultBranchRef": {"name": "main"},
            }
        }
        history_data = {
            "repository": {
                "defaultBranchRef": {
                    "target": {
                        "history": {
                            "nodes": [{"oid": commit_sha}],
                            "pageInfo": {"hasNextPage": True},
                        }
                    }
                }
            }
        }
        with patch.object(
            validator,
            "_read_github_graphql",
            side_effect=[(object_data, None), (history_data, None)],
        ):
            error = validator._verify_github_repository_commit(
                "heimgewebe/wgx", commit_sha, root_tree_sha
            )

        self.assertEqual(
            error,
            "GitHub default-branch history timestamp is not uniquely bounded",
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

    def test_non_consumer_wgx_source_url_requires_pinned_evidence(self) -> None:
        target = self.payload["authority_boundary"]["owners"]["ci_conclusions"][
            "source_url"
        ]
        records, findings = self.load_evidence(self.evidence)
        self.assertEqual(findings, [])
        records.pop(target)

        with patch.object(validator, "_load_pinned_evidence", return_value=records):
            validation_findings = self.validate(self.payload)

        self.assertTrue(
            any(
                item
                == "WGX source URL lacks checked-in pinned source evidence: " + target
                for item in validation_findings
            )
        )

    def test_wgx_source_identity_is_case_insensitive_for_proof_requirement(self) -> None:
        payload = copy.deepcopy(self.payload)
        owner = payload["authority_boundary"]["owners"]["ci_conclusions"]
        owner["source_url"] = owner["source_url"].replace(
            "heimgewebe/wgx", "Heimgewebe/WGX", 1
        )

        findings = self.validate(payload)

        self.assertTrue(
            any(
                item
                == "WGX source URL lacks checked-in pinned source evidence: "
                + owner["source_url"]
                for item in findings
            )
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

    def test_integrity_publication_is_repository_maintenance_not_cli(self) -> None:
        command_ids = {item["id"] for item in self.payload["operational_commands"]}
        self.assertNotIn("integrity", command_ids)
        self.assertFalse((ROOT / "cmd/integrity.bash").exists())
        workflow = (ROOT / ".github/workflows/wgx-integrity.yml").read_text(encoding="utf-8")
        self.assertIn("bash scripts/generate-integrity-report.sh", workflow)
        self.assertNotIn("./wgx integrity", workflow)
        self.assertNotIn("Publish Event", workflow)
        self.assertFalse((ROOT / "modules/heimgeist.bash").exists())

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

    def test_public_command_inventory_is_minimal_runner_abi(self) -> None:
        command_ids = {item["id"] for item in self.payload["operational_commands"]}
        self.assertEqual(command_ids, {"task", "tasks", "validate"})
        discovered = {path.stem for path in (ROOT / "cmd").glob("*.bash")}
        self.assertEqual(discovered, command_ids)

    def test_missing_operational_command_is_rejected(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["operational_commands"] = [
            item for item in payload["operational_commands"] if item["id"] != "validate"
        ]
        findings = self.validate(payload)
        self.assertTrue(any("operational command inventory is missing: validate" in item for item in findings))

    def test_delegated_execution_must_disclose_host_effects(self) -> None:
        payload = copy.deepcopy(self.payload)
        command = next(item for item in payload["operational_commands"] if item["id"] == "task")
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
                "workflow pull_request trigger misses required path: cmd/validate.bash" in item
                for item in findings
            )
        )

    def test_restored_executable_templates_keep_tasks(self) -> None:
        expected_tasks = {
            "templates/.wgx/profile.yml": {"integrity", "test", "lint"},
            "templates/profile.template.yml": {"test"},
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
