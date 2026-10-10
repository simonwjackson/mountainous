#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 openssl
import copy
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(os.environ.get("GITHUB_ACTIONS_PREFLIGHT_SOURCE", Path(__file__).resolve().parents[1] / "modules" / "github-actions-preflight.py"))
spec = importlib.util.spec_from_file_location("github_actions_preflight", SOURCE)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class GithubActionsPolicyTests(unittest.TestCase):
    def setUp(self):
        self.group = {
            "name": preflight.GROUP,
            "visibility": "selected",
            "allows_public_repositories": True,
            "restricted_to_workflows": True,
            "selected_workflows": [preflight.WORKFLOW],
        }
        self.repositories = {"total_count": 1, "repositories": [{"full_name": preflight.REPOSITORY}]}

    def test_accepts_only_the_manual_main_workflow_for_forgerie(self):
        preflight.validate_policy(self.group, self.repositories)

    def test_rejects_public_repository_access_without_workflow_restrictions(self):
        self.group["restricted_to_workflows"] = False
        with self.assertRaisesRegex(ValueError, "workflow restrictions"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_changed_pr_workflow_refs(self):
        for ref in ["refs/pull/1/merge", "refs/heads/feature", "main", "refs/tags/v1"]:
            with self.subTest(ref=ref):
                self.group["selected_workflows"] = [preflight.WORKFLOW.replace("refs/heads/main", ref)]
                with self.assertRaisesRegex(ValueError, "exact main workflow"):
                    preflight.validate_policy(self.group, self.repositories)

    def test_rejects_additional_workflows(self):
        self.group["selected_workflows"].append("forgerie/forgerie/.github/workflows/ci.yml@refs/heads/main")
        with self.assertRaisesRegex(ValueError, "exact main workflow"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_additional_repositories(self):
        self.repositories["total_count"] = 2
        self.repositories["repositories"].append({"full_name": "forgerie/other"})
        with self.assertRaisesRegex(ValueError, "repository"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_repository_substitution(self):
        self.repositories["repositories"] = [{"full_name": "outsider/forgerie"}]
        with self.assertRaisesRegex(ValueError, "Forgerie repository only"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_missing_policy_fields(self):
        for key in self.group:
            with self.subTest(key=key):
                group = copy.deepcopy(self.group)
                del group[key]
                with self.assertRaises(ValueError):
                    preflight.validate_policy(group, self.repositories)

    def test_rejects_all_repository_access(self):
        self.group["visibility"] = "all"
        with self.assertRaisesRegex(ValueError, "selected repository access"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_default_group(self):
        self.group["name"] = "Default"
        with self.assertRaisesRegex(ValueError, "runner group name"):
            preflight.validate_policy(self.group, self.repositories)

    def test_rejects_non_private_app_key_before_contacting_github(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.pem"
            path.write_text("This is a test fixture, not a key")
            path.chmod(0o644)
            with self.assertRaisesRegex(ValueError, "root-owned regular file with mode 0400"):
                preflight.installation_token(123456, str(path))


if __name__ == "__main__":
    unittest.main()
