import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "features" / "jellyfin" / "bootstrap_state.py"

spec = importlib.util.spec_from_file_location("jellyfin_bootstrap_state", MODULE_PATH)
bootstrap_state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap_state)


class JellyfinBootstrapStateTest(unittest.TestCase):
    def test_waits_through_initialized_server_restart(self):
        calls = []
        public_states = [
            {"StartupWizardCompleted": False, "ServerName": "localhost"},
            {"StartupWizardCompleted": True, "ServerName": "zao"},
        ]

        def api_request(path):
            calls.append(path)
            if path == "/System/Info/Public":
                return public_states.pop(0)
            if path == "/Startup/Configuration":
                return {"UICulture": "en-US"}
            raise AssertionError(f"unexpected API path: {path}")

        state, public_info, startup_configuration = bootstrap_state.wait_for_startup_state(
            api_request,
            sleep=lambda _: None,
            attempts=2,
            known_initialized=True,
        )

        self.assertEqual("initialized", state)
        self.assertEqual("zao", public_info["ServerName"])
        self.assertIsNone(startup_configuration)
        self.assertEqual(
            [
                "/System/Info/Public",
                "/System/Info/Public",
            ],
            calls,
        )

    def test_rechecks_public_info_when_startup_endpoint_is_unavailable(self):
        public_states = [
            {"StartupWizardCompleted": False},
            {"StartupWizardCompleted": True, "ServerName": "zao"},
        ]

        def api_request(path):
            if path == "/System/Info/Public":
                return public_states.pop(0)
            raise RuntimeError("Jellyfin API GET /Startup/Configuration failed: 401")

        state, public_info, configuration = bootstrap_state.wait_for_startup_state(
            api_request,
            sleep=lambda _: None,
            attempts=2,
        )

        self.assertEqual("initialized", state)
        self.assertEqual("zao", public_info["ServerName"])
        self.assertIsNone(configuration)

    def test_returns_genuine_first_run_configuration(self):
        startup_configuration = {"UICulture": "en-US"}

        def api_request(path):
            if path == "/System/Info/Public":
                return {"StartupWizardCompleted": False}
            if path == "/Startup/Configuration":
                return startup_configuration
            raise AssertionError(f"unexpected API path: {path}")

        state, public_info, configuration = bootstrap_state.wait_for_startup_state(
            api_request,
            sleep=lambda _: None,
            attempts=1,
        )

        self.assertEqual("first-run", state)
        self.assertFalse(public_info["StartupWizardCompleted"])
        self.assertEqual(startup_configuration, configuration)

    def test_returns_initialized_server_immediately(self):
        calls = []

        def api_request(path):
            calls.append(path)
            return {"StartupWizardCompleted": True, "ServerName": "zao"}

        state, public_info, configuration = bootstrap_state.wait_for_startup_state(
            api_request,
            sleep=lambda _: None,
            attempts=1,
        )

        self.assertEqual("initialized", state)
        self.assertEqual("zao", public_info["ServerName"])
        self.assertIsNone(configuration)
        self.assertEqual(["/System/Info/Public"], calls)

    def test_times_out_when_neither_state_is_ready(self):
        def api_request(path):
            if path == "/System/Info/Public":
                return {"StartupWizardCompleted": False}
            raise RuntimeError("startup endpoint unavailable")

        with self.assertRaisesRegex(RuntimeError, "Timed out waiting for Jellyfin startup state"):
            bootstrap_state.wait_for_startup_state(
                api_request,
                sleep=lambda _: None,
                attempts=2,
            )


if __name__ == "__main__":
    unittest.main()
