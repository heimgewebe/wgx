#!/usr/bin/env python3
"""Fail-closed validation for WGX capability, consumer, command, and CI evidence."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

DEFAULT_MAP = Path("docs/operator-ecosystem-capabilities.v1.json")
RETAINED = {"retained_multi_consumer", "retained_fleet_invariance"}
PRESERVED = {"preserved_unproven"}
RETIRED = {"retired_replaced"}
REQUIRED_RETAINED_IDS = {
    "repository-guard-router",
    "repository-smoke-router",
    "fleet-static-guard-invariants",
    "metrics-contract-compatibility",
    "cross-repository-compatibility-matrix",
}
REQUIRED_PRESERVED_IDS = {"wgx-profile-starter-templates"}
REQUIRED_CATEGORIES = {"guard", "smoke", "metrics", "compatibility", "template"}
FORBIDDEN_AUTHORITY = {
    "bureau_task_coordination",
    "grabowski_deployment_or_process_authority",
    "generic_cross_repository_host_authority",
}
ALLOWED_CAPABILITY_AUTHORITY = {
    "repository_verification_adapter",
    "repository_scoped_developer_tool",
    "compatibility_check",
    "none_unproven",
}
ALLOWED_COMMAND_STATUS = {"active", "placeholder", "unavailable"}
ALLOWED_COMMAND_CLASSIFICATION = {
    "repository_scoped_observation",
    "repository_scoped_observation_optional_mutation",
    "repository_scoped_developer_mutation",
    "repository_scoped_destructive_mutation",
    "repository_scoped_verification",
    "host_observation",
    "external_repository_service_mutation",
    "delegated_profile_execution",
    "delegated_repository_test_execution",
    "operator_selected_host_state_mutation",
    "unavailable",
}
REQUIRED_COMMAND_CLASSIFICATIONS = {
    "clean": "repository_scoped_developer_mutation",
    "reload": "repository_scoped_destructive_mutation",
    "send": "external_repository_service_mutation",
    "run": "delegated_profile_execution",
    "task": "delegated_profile_execution",
}
_EVENT_RE = re.compile(r"^  (pull_request|push):(?:\s.*)?$")


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _https_url(value: Any) -> bool:
    if not _nonempty_string(value):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def _source_url(value: Any) -> bool:
    if not _https_url(value):
        return False
    parsed = urlparse(value)
    return parsed.netloc == "github.com" and "/blob/" in parsed.path


def _source_url_matches(value: Any, repository: Any, evidence_path: Any) -> bool:
    if not (
        _source_url(value)
        and _nonempty_string(repository)
        and _nonempty_string(evidence_path)
    ):
        return False
    parsed = urlparse(value)
    prefix = f"/{repository}/blob/"
    if not parsed.path.startswith(prefix):
        return False
    remainder = parsed.path[len(prefix) :]
    _, separator, linked_path = remainder.partition("/")
    return bool(separator) and linked_path == evidence_path.lstrip("/")


def _local_paths(
    value: Any, root: Path, prefix: str, findings: list[str], *, required: bool = True
) -> list[str]:
    if not isinstance(value, list) or (required and not value):
        findings.append(f"{prefix} must be a non-empty array")
        return []
    paths: list[str] = []
    for index, item in enumerate(value):
        if not _nonempty_string(item):
            findings.append(f"{prefix}[{index}] must be a non-empty path")
            continue
        paths.append(item)
        if not (root / item).is_file():
            findings.append(f"{prefix} path is missing: {item}")
    return paths


def _validate_alternative(
    alternative: Any, prefix: str, findings: list[str], *, require_source: bool
) -> None:
    if not isinstance(alternative, dict):
        findings.append(f"{prefix} is required")
        return
    if not _nonempty_string(alternative.get("owner")):
        findings.append(f"{prefix}.owner is required")
    if not _nonempty_string(alternative.get("path")):
        findings.append(f"{prefix}.path is required")
    if require_source and not _source_url(alternative.get("source_url")):
        findings.append(f"{prefix}.source_url must be source-linked")


def _workflow_patterns(path: Path) -> dict[str, list[str]]:
    patterns = {"pull_request": [], "push": []}
    current_event: str | None = None
    in_paths = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        event_match = _EVENT_RE.match(raw_line)
        if event_match:
            current_event = event_match.group(1)
            in_paths = False
            continue
        if current_event and re.match(r"^  \S", raw_line):
            current_event = None
            in_paths = False
            continue
        if current_event and re.match(r"^    paths:\s*$", raw_line):
            in_paths = True
            continue
        if in_paths:
            item = re.match(r"^      -\s+(.+?)\s*$", raw_line)
            if item:
                patterns[current_event].append(item.group(1).strip("'\""))
                continue
            if raw_line.strip() and not raw_line.lstrip().startswith("#"):
                in_paths = False
    return patterns


def _covered(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def validate(payload: Any, root: Path) -> list[str]:
    findings: list[str] = []

    if not isinstance(payload, dict):
        return ["document root must be an object"]
    if payload.get("schema_version") != 1:
        findings.append("schema_version must equal 1")
    if payload.get("task") != "OPERATOR-ECOSYSTEM-REDUNDANCY-V1-T009":
        findings.append("task must identify OPERATOR-ECOSYSTEM-REDUNDANCY-V1-T009")

    boundary = payload.get("authority_boundary")
    if not isinstance(boundary, dict):
        findings.append("authority_boundary must be an object")
    else:
        excluded = boundary.get("does_not_own")
        if (
            not isinstance(excluded, list)
            or len(excluded) != len(set(excluded))
            or set(excluded) != FORBIDDEN_AUTHORITY
        ):
            findings.append(
                "authority_boundary.does_not_own must contain exactly "
                "bureau_task_coordination, grabowski_deployment_or_process_authority, "
                "and generic_cross_repository_host_authority"
            )
        owners = boundary.get("owners")
        if not isinstance(owners, dict) or not owners:
            findings.append("authority_boundary.owners must be a non-empty object")
            owners = {}
        for authority in FORBIDDEN_AUTHORITY:
            record = owners.get(authority)
            if not isinstance(record, dict):
                findings.append(f"authority_boundary.owners.{authority} must be an object")
                continue
            owner = record.get("owner")
            if not _nonempty_string(owner):
                findings.append(f"authority_boundary.owners.{authority}.owner is required")
            elif "wgx" in owner.lower():
                findings.append(f"authority contradiction: WGX cannot own {authority}")
            if not _source_url(record.get("source_url")):
                findings.append(
                    f"authority_boundary.owners.{authority}.source_url must be source-linked"
                )
        for authority, record in owners.items():
            if not isinstance(record, dict) or not _nonempty_string(record.get("owner")):
                findings.append(f"authority_boundary.owners.{authority}.owner is required")
            elif not _source_url(record.get("source_url")):
                findings.append(
                    f"authority_boundary.owners.{authority}.source_url must be source-linked"
                )
        boundary_text = json.dumps(boundary, sort_keys=True).lower()
        if "no_generic_host_mutation" in boundary_text or '"generic_host_mutation"' in boundary_text:
            findings.append(
                "authority contradiction: generic host mutation may only be narrowed to "
                "generic_cross_repository_host_authority"
            )
        for field in ("repository_scoped_mutation", "delegated_execution"):
            if not _nonempty_string(boundary.get(field)):
                findings.append(f"authority_boundary.{field} is required")
        non_claims = boundary.get("explicit_non_claims")
        if not isinstance(non_claims, list) or len(non_claims) < 3 or not all(
            _nonempty_string(item) for item in non_claims
        ):
            findings.append("authority_boundary.explicit_non_claims needs three statements")

    capabilities = payload.get("capabilities")
    if not isinstance(capabilities, list) or not capabilities:
        return findings + ["capabilities must be a non-empty array"]

    seen_ids: set[str] = set()
    retained_ids: set[str] = set()
    preserved_ids: set[str] = set()
    covered_categories: set[str] = set()
    workflow_surfaces: set[str] = set()

    for index, capability in enumerate(capabilities):
        label = f"capabilities[{index}]"
        if not isinstance(capability, dict):
            findings.append(f"{label} must be an object")
            continue

        capability_id = capability.get("id")
        if not _nonempty_string(capability_id):
            findings.append(f"{label}.id must be a non-empty string")
            capability_id = label
        elif capability_id in seen_ids:
            findings.append(f"duplicate capability id: {capability_id}")
        else:
            seen_ids.add(capability_id)
        prefix = f"capability {capability_id}"

        category = capability.get("category")
        if category not in REQUIRED_CATEGORIES:
            findings.append(f"{prefix}: unsupported category {category!r}")
        else:
            covered_categories.add(category)

        disposition = capability.get("disposition")
        if disposition not in RETAINED | PRESERVED | RETIRED:
            findings.append(f"{prefix}: unsupported disposition {disposition!r}")
        if capability.get("authority") not in ALLOWED_CAPABILITY_AUTHORITY:
            findings.append(f"{prefix}: unsupported or contradictory authority")

        surfaces = capability.get("surfaces")
        if not isinstance(surfaces, list) or not surfaces or not all(
            _nonempty_string(item) for item in surfaces
        ):
            findings.append(f"{prefix}: surfaces must be a non-empty string array")
            surfaces = []
        workflow_surfaces.update(surfaces)

        _local_paths(
            capability.get("local_evidence_paths"),
            root,
            f"{prefix}.local_evidence_paths",
            findings,
        )

        consumers = capability.get("consumers")
        if not isinstance(consumers, list):
            findings.append(f"{prefix}: consumers must be an array")
            consumers = []

        consumer_repositories: set[str] = set()
        for consumer_index, consumer in enumerate(consumers):
            consumer_label = f"{prefix} consumer[{consumer_index}]"
            if not isinstance(consumer, dict):
                findings.append(f"{consumer_label} must be an object")
                continue
            repository = consumer.get("repository")
            evidence_path = consumer.get("evidence_path")
            if not _nonempty_string(repository) or repository.count("/") != 1:
                findings.append(f"{consumer_label}: repository must use owner/name")
            elif repository in consumer_repositories:
                findings.append(f"{prefix}: duplicate consumer repository {repository}")
            else:
                consumer_repositories.add(repository)
            if not _nonempty_string(evidence_path):
                findings.append(f"{consumer_label}: evidence_path is required")
            if not _source_url_matches(
                consumer.get("source_url"), repository, evidence_path
            ):
                findings.append(
                    f"{consumer_label}: source_url must link repository/evidence_path exactly"
                )
            if not _nonempty_string(consumer.get("canonical_invocation")):
                findings.append(f"{consumer_label}: canonical_invocation is required")
            alternative = consumer.get("repository_native_alternative")
            if not isinstance(alternative, dict):
                findings.append(f"{consumer_label}: repository_native_alternative is required")
            else:
                alt_path = alternative.get("path")
                if not _nonempty_string(alt_path):
                    findings.append(f"{consumer_label}: alternative path is required")
                if not _source_url_matches(
                    alternative.get("source_url"), repository, alt_path
                ):
                    findings.append(
                        f"{consumer_label}: alternative source_url must link its repository/path"
                    )

        invariance = capability.get("invariance_benefit")
        has_invariance = (
            isinstance(invariance, dict)
            and _nonempty_string(invariance.get("claim"))
            and isinstance(invariance.get("evidence_sources"), list)
            and bool(invariance["evidence_sources"])
            and all(_source_url(item) for item in invariance["evidence_sources"])
        )

        if disposition in RETAINED:
            retained_ids.add(capability_id)
            for surface in surfaces:
                if not (root / surface).is_file():
                    findings.append(f"{prefix}: retained surface is missing: {surface}")
            if not consumers:
                findings.append(f"{prefix}: retained capability needs demonstrated consumers")
            if disposition == "retained_multi_consumer" and len(consumer_repositories) < 2:
                findings.append(f"{prefix}: retained_multi_consumer needs two consumers")
            if disposition == "retained_fleet_invariance" and not has_invariance:
                findings.append(
                    f"{prefix}: retained_fleet_invariance needs source-linked invariance evidence"
                )
            _validate_alternative(
                capability.get("ecosystem_alternative"),
                f"{prefix}.ecosystem_alternative",
                findings,
                require_source=True,
            )
            if capability_id == "cross-repository-compatibility-matrix" and (
                consumer_repositories != {"heimgewebe/wgx"}
            ):
                findings.append(
                    f"{prefix}: compatibility targets must not be recorded as consumers"
                )

        if disposition in PRESERVED:
            preserved_ids.add(capability_id)
            for surface in surfaces:
                if not (root / surface).exists():
                    findings.append(f"{prefix}: preserved surface is missing: {surface}")
            if consumers:
                findings.append(f"{prefix}: preserved_unproven must not claim consumers")
            if capability.get("replacement") is not None:
                findings.append(f"{prefix}: preserved_unproven cannot claim a replacement")
            migration = capability.get("migration_record")
            if (
                not isinstance(migration, dict)
                or migration.get("decision") != "retirement_reversed"
                or not _source_url(migration.get("incompatible_candidate_url"))
            ):
                findings.append(
                    f"{prefix}: preserved template requires retirement_reversed migration evidence"
                )

        if disposition in RETIRED:
            replacement = capability.get("replacement")
            _validate_alternative(
                replacement, f"{prefix}.replacement", findings, require_source=True
            )
            if isinstance(replacement, dict):
                for field in ("distribution_url", "ci_coverage_url"):
                    if not _source_url(replacement.get(field)):
                        findings.append(f"{prefix}: replacement.{field} must be source-linked")
                _local_paths(
                    replacement.get("local_coverage_paths"),
                    root,
                    f"{prefix}.replacement.local_coverage_paths",
                    findings,
                )
            for surface in surfaces:
                if (root / surface).exists():
                    findings.append(f"{prefix}: retired surface still exists: {surface}")

    missing_categories = REQUIRED_CATEGORIES - covered_categories
    if missing_categories:
        findings.append(
            "capability inventory is missing categories: " + ", ".join(sorted(missing_categories))
        )
    missing_retained = REQUIRED_RETAINED_IDS - retained_ids
    if missing_retained:
        findings.append(
            "required retained capability IDs are missing: "
            + ", ".join(sorted(missing_retained))
        )
    missing_preserved = REQUIRED_PRESERVED_IDS - preserved_ids
    if missing_preserved:
        findings.append(
            "required preserved capability IDs are missing: "
            + ", ".join(sorted(missing_preserved))
        )

    commands = payload.get("operational_commands")
    if not isinstance(commands, list) or not commands:
        findings.append("operational_commands must be a non-empty array")
        commands = []
    command_ids: set[str] = set()
    command_surfaces: set[str] = set()
    for index, command in enumerate(commands):
        label = f"operational_commands[{index}]"
        if not isinstance(command, dict):
            findings.append(f"{label} must be an object")
            continue
        command_id = command.get("id")
        prefix = f"command {command_id}"
        if not _nonempty_string(command_id):
            findings.append(f"{label}.id must be a non-empty string")
            continue
        if command_id in command_ids:
            findings.append(f"duplicate operational command id: {command_id}")
        command_ids.add(command_id)
        surface = command.get("surface")
        expected_surface = f"cmd/{command_id}.bash"
        if surface != expected_surface:
            findings.append(f"{prefix}: surface must equal {expected_surface}")
        elif not (root / surface).is_file():
            findings.append(f"{prefix}: command surface is missing: {surface}")
        else:
            command_surfaces.add(surface)
        if command.get("status") not in ALLOWED_COMMAND_STATUS:
            findings.append(f"{prefix}: unsupported status")
        classification = command.get("classification")
        if classification not in ALLOWED_COMMAND_CLASSIFICATION:
            findings.append(f"{prefix}: unsupported classification")
        required_classification = REQUIRED_COMMAND_CLASSIFICATIONS.get(command_id)
        if required_classification and classification != required_classification:
            findings.append(
                f"{prefix}: classification must be {required_classification}"
            )
        effects = command.get("effects")
        if not _nonempty_string(effects):
            findings.append(f"{prefix}: effects are required")
        if command_id in {"run", "task"} and (
            "host effects" not in str(effects).lower()
            or "does not confine" not in str(effects).lower()
        ):
            findings.append(
                f"{prefix}: delegated execution must disclose unconfined host effects"
            )
        _local_paths(
            command.get("consumer_evidence_paths"),
            root,
            f"{prefix}.consumer_evidence_paths",
            findings,
        )
        _validate_alternative(
            command.get("alternative"),
            f"{prefix}.alternative",
            findings,
            require_source=False,
        )

    discovered_commands = {path.stem for path in (root / "cmd").glob("*.bash")}
    if command_ids != discovered_commands:
        missing = discovered_commands - command_ids
        extra = command_ids - discovered_commands
        if missing:
            findings.append(
                "operational command inventory is missing: " + ", ".join(sorted(missing))
            )
        if extra:
            findings.append(
                "operational command inventory has unknown commands: "
                + ", ".join(sorted(extra))
            )

    workflow_contract = payload.get("workflow_contract")
    if not isinstance(workflow_contract, dict):
        findings.append("workflow_contract must be an object")
    else:
        workflow_path = workflow_contract.get("path")
        if not _nonempty_string(workflow_path) or not (root / workflow_path).is_file():
            findings.append("workflow_contract.path must identify an existing workflow")
        else:
            validator_paths = _local_paths(
                workflow_contract.get("validator_contract_paths"),
                root,
                "workflow_contract.validator_contract_paths",
                findings,
            )
            required_trigger_paths = (
                workflow_surfaces | command_surfaces | set(validator_paths)
            )
            try:
                event_patterns = _workflow_patterns(root / workflow_path)
            except OSError as exc:
                findings.append(f"cannot read workflow contract: {exc}")
            else:
                for event in ("pull_request", "push"):
                    for required_path in sorted(required_trigger_paths):
                        if not _covered(required_path, event_patterns[event]):
                            findings.append(
                                f"workflow {event} trigger misses required path: {required_path}"
                            )

    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("map_path", nargs="?", type=Path, default=DEFAULT_MAP)
    args = parser.parse_args(argv)

    try:
        payload = json.loads(args.map_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot load {args.map_path}: {exc}", file=sys.stderr)
        return 1

    root = Path(__file__).resolve().parent.parent
    findings = validate(payload, root)
    if findings:
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        return 1
    print(f"PASS: {args.map_path} capability boundaries and consumer evidence are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
