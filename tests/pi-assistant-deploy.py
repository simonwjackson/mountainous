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
        self.assertEqual(deploy.restart_units(False), ["assistant-app-*", "atlas"])

    def test_enabled_preserves_runtime_restart_selection(self):
        self.assertEqual(
            deploy.restart_units(True),
            [
                "assistant-app-*",
                "pi-assistant-simon",
                "pi-assistant-laure",
                "pi-assistant-household",
                "assistant-tsgo",
                "atlas",
            ],
        )

    def test_invalid_configuration_fails_closed(self):
        for value in (None, "false", 0, {}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                deploy.restart_units(value)


if __name__ == "__main__":
    unittest.main()
