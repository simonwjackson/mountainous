#!/usr/bin/env python3
"""Exercise restart selection without Nix, SSH, builds, or running services."""

import importlib.machinery
import importlib.util
import sys
import unittest

loader = importlib.machinery.SourceFileLoader("deploy", sys.argv.pop(1))
spec = importlib.util.spec_from_loader(loader.name, loader)
deploy = importlib.util.module_from_spec(spec)
loader.exec_module(deploy)


class RestartSelection(unittest.TestCase):
    def test_paused_only_restarts_live_apps_and_atlas(self):
        self.assertEqual(
            deploy.restart_units(False, True), ["assistant-app-*", "atlas"]
        )

    def test_enabled_preserves_runtime_restart_selection(self):
        self.assertEqual(
            deploy.restart_units(True, True),
            [
                "assistant-app-*",
                "pi-assistant-simon",
                "pi-assistant-laure",
                "pi-assistant-household",
                "assistant-tsgo",
                "atlas",
            ],
        )

    def test_retired_atlas_only_restarts_live_apps_when_instances_paused(self):
        self.assertEqual(deploy.restart_units(False, False), ["assistant-app-*"])

    def test_retired_atlas_does_not_disable_enabled_pi_instances(self):
        self.assertEqual(
            deploy.restart_units(True, False), deploy.restart_units(True, True)[:-1]
        )

    def test_invalid_configuration_fails_closed(self):
        for value in (None, "false", 0, {}):
            for flags in ((value, False), (False, value)):
                with self.subTest(flags=flags), self.assertRaises(ValueError):
                    deploy.restart_units(*flags)


if __name__ == "__main__":
    unittest.main()
