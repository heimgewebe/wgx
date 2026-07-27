#!/usr/bin/env python3
"""Fail-closed validation for WGX capability, consumer, command, and CI evidence."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
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
CAPABILITY_CATEGORIES = {
    "repository-guard-router": "guard",
    "repository-smoke-router": "smoke",
    "fleet-static-guard-invariants": "guard",
    "metrics-contract-compatibility": "metrics",
    "cross-repository-compatibility-matrix": "compatibility",
    "wgx-tools-module-guard": "tool",
    "scheduled-integrity-publication": "integrity",
    "versioned-release-publication": "publication",
    "wgx-profile-starter-templates": "template",
}
REQUIRED_CAPABILITY_SURFACES = {
    "repository-guard-router": {".github/workflows/wgx-guard.yml"},
    "repository-smoke-router": {
        ".github/workflows/wgx-smoke.yml",
        "scripts/check_wgx_smoke_contract.py",
        "scripts/check_wgx_guard_action_pins.py",
    },
    "fleet-static-guard-invariants": {
        "modules/guard.bash",
        "guards/ci-deps.guard.sh",
        "guards/contracts_meta_guard.py",
        "guards/contracts_ownership.guard.sh",
        "guards/data_flow_guard.py",
        "guards/insights_guard.py",
        "guards/integrity.guard.sh",
    },
    "metrics-contract-compatibility": {
        ".github/workflows/metrics.yml",
        "scripts/wgx-metrics-snapshot.sh",
        "scripts/just-dispatch.sh",
        "tests/contracts_validate.bats",
        "tests/metrics_snapshot.bats",
    },
    "cross-repository-compatibility-matrix": {
        ".github/workflows/compat-on-demand.yml",
        ".github/actions/wgx-check/action.yml",
    },
    "wgx-tools-module-guard": {
        ".github/workflows/wgx-tools-guard.yml",
        ".wgx-tools/modules/.gitkeep",
    },
    "scheduled-integrity-publication": {
        ".github/workflows/wgx-integrity.yml",
        "cmd/integrity.bash",
        "modules/integrity.bash",
        "guards/integrity.guard.sh",
        "docs/integrity-architecture.md",
        "tests/integrity.bats",
        "tests/guard_integrity.bats",
    },
    "versioned-release-publication": {".github/workflows/release.yml"},
    "wgx-profile-starter-templates": {
        "templates/profiles/docs-only.yml",
        "templates/profiles/meta.yml",
        "templates/profiles/python-service.yml",
        "templates/profiles/rust-service.yml",
        "templates/profile.template.yml",
        "templates/.wgx/profile.yml",
        "templates/.wgx/profile.local.example.yml",
        "templates/.gitkeep",
        "templates/docs/README.additions.md",
    },
}
SURFACE_CONTENT_REQUIREMENTS = {
    ".github/workflows/metrics.yml": {
        'cron: "0 * * * *"',
        "HAUSKI_POST_URL: ${{ secrets.HAUSKI_METRICS_URL }}",
        "Optional POST to hausKI",
        "uses: actions/upload-artifact@v4",
        "retention-days: 7",
    },
    ".github/workflows/wgx-tools-guard.yml": {
        "push:",
        "pull_request:",
        "shellcheck -x \"${files[@]}\"",
    },
    ".github/workflows/wgx-integrity.yml": {
        "schedule:",
        "workflow_dispatch:",
        "cron: '0 6 * * *'",
        "./wgx integrity --update",
        "uses: softprops/action-gh-release@",
        "gh release view integrity",
    },
    ".github/workflows/release.yml": {
        "push:",
        "workflow_dispatch:",
        "- 'v*.*.*'",
        "uses: softprops/action-gh-release@5be0e66d93ac7ed76da52eca8bb058f665c3a5fe",
    },
}
REQUIRED_RETAINED_IDS = set(CAPABILITY_CATEGORIES) - {
    "wgx-profile-starter-templates"
}
REQUIRED_PRESERVED_IDS = {"wgx-profile-starter-templates"}
REQUIRED_CATEGORIES = set(CAPABILITY_CATEGORIES.values())
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
    "quick": "external_repository_service_mutation",
    "reload": "repository_scoped_destructive_mutation",
    "send": "external_repository_service_mutation",
    "sync-remote": "repository_scoped_destructive_mutation",
    "run": "delegated_profile_execution",
    "task": "delegated_profile_execution",
}
REQUIRED_COMMAND_DELEGATIONS = {
    "quick": ["guard", "send"],
    "sync-remote": ["reload"],
}
AUTHORITY_SOURCE_BINDINGS = {
    "bureau_task_coordination": ("heimgewebe/bureau", "docs/ownership.md"),
    "grabowski_deployment_or_process_authority": (
        "heimgewebe/grabowski",
        "README.md",
    ),
    "generic_cross_repository_host_authority": (
        "heimgewebe/grabowski",
        "README.md",
    ),
    "repository_changes": (
        "heimgewebe/wgx",
        "cmd/reload.bash",
    ),
    "ci_conclusions": (
        "heimgewebe/wgx",
        ".github/workflows/wgx-guard.yml",
    ),
}
PINNED_EVIDENCE_PATH = Path("docs/operator-ecosystem-source-evidence.v1.json")
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
    if parsed.netloc != "github.com" or "/blob/" not in parsed.path:
        return False
    _, _, remainder = parsed.path.partition("/blob/")
    ref, separator, _ = remainder.partition("/")
    return bool(separator) and bool(re.fullmatch(r"[0-9a-f]{40}", ref))


def _source_url_matches(value: Any, repository: Any, evidence_path: Any) -> bool:
    if not (
        _source_url(value)
        and _nonempty_string(repository)
        and _nonempty_string(evidence_path)
    ):
        return False
    candidate_path = Path(evidence_path)
    if candidate_path.is_absolute() or ".." in candidate_path.parts:
        return False
    parsed = urlparse(value)
    prefix = f"/{repository}/blob/"
    if not parsed.path.startswith(prefix):
        return False
    remainder = parsed.path[len(prefix) :]
    _, separator, linked_path = remainder.partition("/")
    return bool(separator) and linked_path == evidence_path.lstrip("/")


def _safe_local_path(
    value: Any,
    root: Path,
    prefix: str,
    findings: list[str],
    *,
    kind: str = "file",
) -> Path | None:
    if not _nonempty_string(value):
        findings.append(f"{prefix} must be a non-empty path")
        return None
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        findings.append(f"{prefix} must be repository-relative without parent traversal")
        return None
    try:
        resolved_root = root.resolve(strict=True)
        resolved = (root / candidate).resolve(strict=False)
        resolved.relative_to(resolved_root)
    except (OSError, RuntimeError, ValueError):
        findings.append(f"{prefix} escapes the repository root")
        return None
    if kind == "file" and not resolved.is_file():
        findings.append(f"{prefix} path is missing: {value}")
    elif kind == "exists" and not resolved.exists():
        findings.append(f"{prefix} path is missing: {value}")
    return resolved


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
        _safe_local_path(item, root, f"{prefix}[{index}]", findings)
    return paths


def _validate_alternative(
    alternative: Any,
    prefix: str,
    findings: list[str],
    *,
    expected_repository: str | None = None,
    require_source: bool,
) -> None:
    if not isinstance(alternative, dict):
        findings.append(f"{prefix} is required")
        return
    availability = alternative.get("availability", "available")
    if availability == "none_identified":
        if not _nonempty_string(alternative.get("rationale")):
            findings.append(f"{prefix}.rationale is required when no alternative is identified")
        for field in ("owner", "path", "source_url"):
            if alternative.get(field) not in (None, ""):
                findings.append(
                    f"{prefix}.{field} must be absent when no alternative is identified"
                )
        return
    if availability != "available":
        findings.append(f"{prefix}.availability must be available or none_identified")
        return
    if not _nonempty_string(alternative.get("owner")):
        findings.append(f"{prefix}.owner is required")
    if not _nonempty_string(alternative.get("path")):
        findings.append(f"{prefix}.path is required")
    if require_source:
        source_url = alternative.get("source_url")
        if expected_repository:
            if alternative.get("owner") != expected_repository:
                findings.append(
                    f"{prefix}.owner must equal expected repository {expected_repository}"
                )
            if not _source_url_matches(
                source_url, expected_repository, alternative.get("path")
            ):
                findings.append(
                    f"{prefix}.source_url must link expected owner/repository/path"
                )
        else:
            owner = alternative.get("owner")
            if _nonempty_string(owner) and owner.count("/") == 1:
                if not _source_url_matches(
                    source_url, owner, alternative.get("path")
                ):
                    findings.append(
                        f"{prefix}.source_url must link declared owner/repository/path"
                    )
            elif not _source_url(source_url):
                findings.append(f"{prefix}.source_url must be source-linked")


def _load_pinned_evidence(root: Path, findings: list[str]) -> dict[str, dict[str, Any]]:
    evidence_path = _safe_local_path(
        str(PINNED_EVIDENCE_PATH),
        root,
        "pinned_source_evidence",
        findings,
    )
    if evidence_path is None or not evidence_path.is_file():
        return {}
    try:
        payload = json.loads(evidence_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        findings.append(f"cannot load pinned source evidence: {exc}")
        return {}
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        findings.append("pinned source evidence schema_version must equal 1")
        return {}
    records = payload.get("sources")
    if not isinstance(records, list):
        findings.append("pinned source evidence sources must be an array")
        return {}
    result: dict[str, dict[str, Any]] = {}
    for index, record in enumerate(records):
        prefix = f"pinned source evidence[{index}]"
        if not isinstance(record, dict):
            findings.append(f"{prefix} must be an object")
            continue
        source_url = record.get("source_url")
        if not _source_url_matches(
            source_url, record.get("repository"), record.get("path")
        ):
            findings.append(f"{prefix} URL/repository/path binding is invalid")
            continue
        if not re.fullmatch(r"[0-9a-f]{40}", str(record.get("blob_sha", ""))):
            findings.append(f"{prefix}.blob_sha must be a full Git object ID")
        content = record.get("content")
        if not _nonempty_string(content):
            findings.append(f"{prefix}.content is required")
            continue
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        if record.get("content_sha256") != digest:
            findings.append(f"{prefix}.content_sha256 does not match content")
        if source_url in result:
            findings.append(f"duplicate pinned source evidence URL: {source_url}")
        result[source_url] = record
    return result


def _authority_prose_findings(payload: Any) -> list[str]:
    prose: list[str] = []

    def collect(value: Any) -> None:
        if isinstance(value, str):
            prose.append(value)
        elif isinstance(value, dict):
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)

    collect(payload)
    contradictions: list[str] = []
    authority_patterns = (
        (r"\bwgx\b.*\b(owns?|controls?|coordinates?|assigns?|completes?|closes?)\b.*\bbureau\b", "Bureau"),
        (r"\bbureau\b.*\b(owned|controlled|coordinated|assigned|completed|closed)\b.*\bwgx\b", "Bureau"),
        (r"\bwgx\b.*\b(has|holds|claims)\b.*\bbureau\b.*\bauthority\b", "Bureau"),
        (r"\bwgx\b.*\b(owns?|controls?|deploys?|manages?)\b.*\bgrabowski\b", "Grabowski"),
        (r"\bgrabowski\b.*\b(owned|controlled|deployed|managed)\b.*\bwgx\b", "Grabowski"),
        (
            r"\bwgx\b.*\b(owns?|controls?|authori[sz]es?|mutates?)\b.*\bcross[- ]repository\b",
            "generic cross-repository authority",
        ),
        (r"\bwgx\b.*\b(besitzt|steuert|koordiniert|weist|schließt)\b.*\bbureau\b", "Bureau"),
        (r"\bwgx\b.*\b(besitzt|steuert|deployt|verwaltet)\b.*\bgrabowski\b", "Grabowski"),
    )
    for text in prose:
        for sentence in re.split(r"[\n.!?]+", text.lower()):
            if re.search(r"\b(does not|cannot|must not|no |nicht|keine|kein)\b", sentence):
                continue
            for pattern, authority in authority_patterns:
                if re.search(pattern, sentence):
                    contradictions.append(
                        f"authority contradiction in prose: WGX claims {authority}"
                    )
                    break
    return sorted(set(contradictions))


def _all_strings(value: Any) -> list[str]:
    result: list[str] = []
    if isinstance(value, str):
        result.append(value)
    elif isinstance(value, dict):
        for child in value.values():
            result.extend(_all_strings(child))
    elif isinstance(value, list):
        for child in value:
            result.extend(_all_strings(child))
    return result


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


def _content_has_invocation(content: str, invocation: str) -> bool:
    expected = invocation.strip()
    return bool(expected) and any(
        line.strip() == expected for line in content.splitlines()
    )


def validate(payload: Any, root: Path) -> list[str]:
    findings: list[str] = []

    if not isinstance(payload, dict):
        return ["document root must be an object"]
    findings.extend(_authority_prose_findings(payload))
    pinned_evidence = _load_pinned_evidence(root, findings)
    historical_wgx_prefix = (
        "https://github.com/heimgewebe/wgx/blob/"
        "c4b41809664353a3cff310dd4d6ef4d75be2ff60/"
    )
    for source_url in sorted(
        {item for item in _all_strings(payload) if item.startswith(historical_wgx_prefix)}
    ):
        if source_url not in pinned_evidence:
            findings.append(
                "historical c4b4180 WGX source URL lacks checked-in source content: "
                f"{source_url}"
            )
    if payload.get("schema_version") != 1:
        findings.append("schema_version must equal 1")
    if payload.get("task") != "OPERATOR-ECOSYSTEM-REDUNDANCY-V1-T009":
        findings.append("task must identify OPERATOR-ECOSYSTEM-REDUNDANCY-V1-T009")

    authority_claim_paths = _local_paths(
        payload.get("authority_claim_paths"),
        root,
        "authority_claim_paths",
        findings,
    )
    for claim_path in authority_claim_paths:
        resolved_claim_path = _safe_local_path(
            claim_path,
            root,
            f"authority claim path {claim_path}",
            findings,
        )
        if resolved_claim_path is not None and resolved_claim_path.is_file():
            findings.extend(
                _authority_prose_findings(
                    resolved_claim_path.read_text(encoding="utf-8")
                )
            )

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
                continue
            expected_binding = AUTHORITY_SOURCE_BINDINGS.get(authority)
            if expected_binding and not _source_url_matches(
                record.get("source_url"), *expected_binding
            ):
                findings.append(
                    f"authority_boundary.owners.{authority}.source_url must link "
                    "the expected owner/repository/path"
                )
            elif not expected_binding and not _source_url(record.get("source_url")):
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
        expected_category = CAPABILITY_CATEGORIES.get(capability_id)
        if expected_category is None:
            findings.append(f"{prefix}: unknown capability ID has no category binding")
        elif category != expected_category:
            findings.append(
                f"{prefix}: category must be {expected_category}, got {category!r}"
            )
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
        else:
            for surface_index, surface in enumerate(surfaces):
                resolved_surface = _safe_local_path(
                    surface,
                    root,
                    f"{prefix}.surfaces[{surface_index}]",
                    findings,
                    kind="exists",
                )
                if (
                    resolved_surface is not None
                    and resolved_surface.is_file()
                    and surface in SURFACE_CONTENT_REQUIREMENTS
                ):
                    content = resolved_surface.read_text(encoding="utf-8")
                    for required_text in SURFACE_CONTENT_REQUIREMENTS[surface]:
                        if required_text not in content:
                            findings.append(
                                f"{prefix}: required behavior is missing from "
                                f"{surface}: {required_text}"
                            )
        missing_surfaces = REQUIRED_CAPABILITY_SURFACES.get(capability_id, set()) - set(
            surfaces
        )
        if missing_surfaces:
            findings.append(
                f"{prefix}: required surfaces are missing: "
                + ", ".join(sorted(missing_surfaces))
            )
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
            invocation = consumer.get("canonical_invocation")
            if not _nonempty_string(invocation):
                findings.append(f"{consumer_label}: canonical_invocation is required")
            evidence_kind = consumer.get("evidence_kind", "pinned_snapshot")
            if repository == "heimgewebe/wgx":
                if evidence_kind != "local_worktree":
                    findings.append(
                        f"{consumer_label}: WGX self-evidence must use local_worktree"
                    )
                local_evidence = _safe_local_path(
                    evidence_path,
                    root,
                    f"{consumer_label}.evidence_path",
                    findings,
                )
                if (
                    local_evidence is not None
                    and local_evidence.is_file()
                    and _nonempty_string(invocation)
                    and not _content_has_invocation(
                        local_evidence.read_text(encoding="utf-8"), invocation
                    )
                ):
                    findings.append(
                        f"{consumer_label}: canonical_invocation is not evidenced "
                        "by local pinned source content"
                    )
                if consumer.get("source_url") not in (None, ""):
                    findings.append(
                        f"{consumer_label}: local_worktree evidence must not use a historical source_url"
                    )
            else:
                if evidence_kind != "pinned_snapshot":
                    findings.append(
                        f"{consumer_label}: external evidence must use pinned_snapshot"
                    )
                source_url = consumer.get("source_url")
                if not _source_url_matches(source_url, repository, evidence_path):
                    findings.append(
                        f"{consumer_label}: source_url must link repository/evidence_path exactly"
                    )
                snapshot = pinned_evidence.get(source_url)
                if snapshot is None:
                    findings.append(
                        f"{consumer_label}: source_url has no checked-in pinned source evidence"
                    )
                elif (
                    _nonempty_string(invocation)
                    and not _content_has_invocation(
                        str(snapshot.get("content", "")), invocation
                    )
                ):
                    findings.append(
                        f"{consumer_label}: canonical_invocation is not evidenced "
                        "by pinned source content"
                    )
            alternative = consumer.get("repository_native_alternative")
            _validate_alternative(
                alternative,
                f"{consumer_label}.repository_native_alternative",
                findings,
                expected_repository=repository,
                require_source=True,
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
                _safe_local_path(
                    surface,
                    root,
                    f"{prefix}.preserved_surface",
                    findings,
                    kind="exists",
                )
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
        else:
            resolved_surface = _safe_local_path(
                surface, root, f"{prefix}.surface", findings
            )
            if resolved_surface is not None and resolved_surface.is_file():
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
        required_delegations = REQUIRED_COMMAND_DELEGATIONS.get(command_id)
        if required_delegations is not None and command.get("delegates_to") != required_delegations:
            findings.append(
                f"{prefix}: delegates_to must equal {required_delegations}"
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
        resolved_workflow = _safe_local_path(
            workflow_path,
            root,
            "workflow_contract.path",
            findings,
        )
        if resolved_workflow is None or not resolved_workflow.is_file():
            findings.append("workflow_contract.path must identify an existing workflow")
        else:
            validator_paths = _local_paths(
                workflow_contract.get("validator_contract_paths"),
                root,
                "workflow_contract.validator_contract_paths",
                findings,
            )
            required_trigger_paths = (
                workflow_surfaces
                | command_surfaces
                | set(validator_paths)
                | set(authority_claim_paths)
            )
            required_trigger_paths.add(str(PINNED_EVIDENCE_PATH))
            try:
                event_patterns = _workflow_patterns(resolved_workflow)
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
