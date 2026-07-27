#!/usr/bin/env python3
"""Validate the WGX capability/consumer and authority-boundary inventory."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

DEFAULT_MAP = Path("docs/operator-ecosystem-capabilities.v1.json")
RETAINED = {"retained_multi_consumer", "retained_fleet_invariance"}
RETIRED = {"retired_replaced"}
FORBIDDEN_AUTHORITY = {
    "task_coordination",
    "deploy_authority",
    "generic_host_mutation",
}


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _source_url(value: Any) -> bool:
    if not _nonempty_string(value):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and parsed.netloc == "github.com" and "/blob/" in parsed.path


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
        if not isinstance(excluded, list) or set(excluded) != FORBIDDEN_AUTHORITY:
            findings.append(
                "authority_boundary.does_not_own must contain exactly task_coordination, "
                "deploy_authority, and generic_host_mutation"
            )
        sources = boundary.get("sources")
        if not isinstance(sources, list) or len(sources) < 2 or not all(
            _source_url(item) for item in sources
        ):
            findings.append("authority_boundary.sources must contain at least two source-linked URLs")

    capabilities = payload.get("capabilities")
    if not isinstance(capabilities, list) or not capabilities:
        return findings + ["capabilities must be a non-empty array"]

    seen_ids: set[str] = set()
    covered_categories: set[str] = set()
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
        if category not in {"guard", "smoke", "metrics", "template"}:
            findings.append(f"{prefix}: unsupported category {category!r}")
        else:
            covered_categories.add(category)

        disposition = capability.get("disposition")
        if disposition not in RETAINED | RETIRED:
            findings.append(f"{prefix}: unsupported disposition {disposition!r}")

        surfaces = capability.get("surfaces")
        if not isinstance(surfaces, list) or not surfaces or not all(
            _nonempty_string(item) for item in surfaces
        ):
            findings.append(f"{prefix}: surfaces must be a non-empty string array")
            surfaces = []

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
            if not _nonempty_string(repository) or "/" not in repository:
                findings.append(f"{consumer_label}: repository must use owner/name")
            elif repository in consumer_repositories:
                findings.append(f"{prefix}: duplicate consumer repository {repository}")
            else:
                consumer_repositories.add(repository)
            if not _source_url(consumer.get("source_url")):
                findings.append(f"{consumer_label}: source_url must be a GitHub blob URL")
            alternative = consumer.get("repository_native_alternative")
            if not isinstance(alternative, dict):
                findings.append(f"{consumer_label}: repository_native_alternative is required")
            else:
                if not _nonempty_string(alternative.get("path")):
                    findings.append(f"{consumer_label}: alternative path is required")
                if not _source_url(alternative.get("source_url")):
                    findings.append(f"{consumer_label}: alternative source_url must be source-linked")

        invariance = capability.get("invariance_benefit")
        has_invariance = (
            isinstance(invariance, dict)
            and _nonempty_string(invariance.get("claim"))
            and isinstance(invariance.get("evidence_sources"), list)
            and bool(invariance["evidence_sources"])
            and all(_source_url(item) for item in invariance["evidence_sources"])
        )

        if disposition in RETAINED:
            for surface in surfaces:
                if not (root / surface).is_file():
                    findings.append(f"{prefix}: retained surface is missing: {surface}")
            if len(consumer_repositories) < 2 and not has_invariance:
                findings.append(
                    f"{prefix}: retained capability needs two consumers or a source-linked "
                    "fleet invariance benefit"
                )
            alternatives = capability.get("repository_native_alternatives", [])
            if alternatives:
                if not isinstance(alternatives, list):
                    findings.append(f"{prefix}: repository_native_alternatives must be an array")
                else:
                    for alt_index, alternative in enumerate(alternatives):
                        alt_label = f"{prefix} repository_native_alternatives[{alt_index}]"
                        if not isinstance(alternative, dict):
                            findings.append(f"{alt_label} must be an object")
                            continue
                        if not _nonempty_string(alternative.get("repository")):
                            findings.append(f"{alt_label}: repository is required")
                        if not _nonempty_string(alternative.get("path")):
                            findings.append(f"{alt_label}: path is required")
                        if not _source_url(alternative.get("source_url")):
                            findings.append(f"{alt_label}: source_url must be source-linked")

        if disposition in RETIRED:
            replacement = capability.get("replacement")
            if not isinstance(replacement, dict):
                findings.append(f"{prefix}: retired capability requires replacement evidence")
            else:
                for field in ("source_url", "distribution_url", "ci_coverage_url"):
                    if not _source_url(replacement.get(field)):
                        findings.append(f"{prefix}: replacement.{field} must be source-linked")
                local_paths = replacement.get("local_coverage_paths")
                if not isinstance(local_paths, list) or not local_paths:
                    findings.append(f"{prefix}: replacement.local_coverage_paths is required")
                else:
                    for local_path in local_paths:
                        if not _nonempty_string(local_path) or not (root / local_path).is_file():
                            findings.append(
                                f"{prefix}: replacement coverage path is missing: {local_path}"
                            )
            for surface in surfaces:
                if (root / surface).exists():
                    findings.append(f"{prefix}: retired surface still exists: {surface}")

    missing_categories = {"guard", "smoke", "metrics", "template"} - covered_categories
    if missing_categories:
        findings.append(
            "capability inventory is missing categories: " + ", ".join(sorted(missing_categories))
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
