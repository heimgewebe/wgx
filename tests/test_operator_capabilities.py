#!/usr/bin/env python3

import copy
import json
import unittest
from pathlib import Path

from scripts.validate_operator_capabilities import DEFAULT_MAP, validate


ROOT = Path(__file__).resolve().parent.parent


class OperatorCapabilitiesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.payload = json.loads((ROOT / DEFAULT_MAP).read_text(encoding="utf-8"))

    def test_repository_inventory_is_valid(self) -> None:
        self.assertEqual(validate(self.payload, ROOT), [])

    def test_retained_capability_requires_consumers_or_invariance(self) -> None:
        payload = copy.deepcopy(self.payload)
        capability = next(
            item for item in payload["capabilities"] if item["id"] == "repository-guard-router"
        )
        capability["consumers"] = capability["consumers"][:1]
        findings = validate(payload, ROOT)
        self.assertTrue(
            any("needs two consumers or a source-linked fleet invariance" in item for item in findings)
        )

    def test_consumer_requires_repository_native_alternative(self) -> None:
        payload = copy.deepcopy(self.payload)
        consumer = payload["capabilities"][0]["consumers"][0]
        del consumer["repository_native_alternative"]
        findings = validate(payload, ROOT)
        self.assertTrue(any("repository_native_alternative is required" in item for item in findings))

    def test_authority_boundary_is_fail_closed(self) -> None:
        payload = copy.deepcopy(self.payload)
        payload["authority_boundary"]["does_not_own"].remove("deploy_authority")
        findings = validate(payload, ROOT)
        self.assertTrue(any("does_not_own must contain exactly" in item for item in findings))

    def test_retired_surface_must_stay_absent(self) -> None:
        payload = copy.deepcopy(self.payload)
        retired = next(
            item for item in payload["capabilities"] if item["id"] == "wgx-profile-starter-templates"
        )
        retired["surfaces"][0] = "README.md"
        findings = validate(payload, ROOT)
        self.assertTrue(any("retired surface still exists: README.md" in item for item in findings))


if __name__ == "__main__":
    unittest.main()
