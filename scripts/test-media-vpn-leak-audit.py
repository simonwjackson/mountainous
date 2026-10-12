#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise the audit's service selection CLI without touching a host or network."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class AuditSelectionTests(unittest.TestCase):
    def test_declared_services_select_only_the_expected_usenet_dns_targets(self):
        selections = {
            "nzbget": ["nzbget.service"],
            "both": ["nzbfast.service", "nzbget.service"],
            "nzbfast": ["nzbfast.service"],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            for mode, downloaders in selections.items():
                expected = downloaders + ["transmission.service", "prowlarr.service"]
                path.write_text(json.dumps({"vpnUnits": expected}))
                result = subprocess.run([sys.executable, str(Path(__file__).with_name("media-vpn-leak-audit.py")),
                    "--config", str(path), "--list-services"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, (mode, result.stderr))
                self.assertEqual(json.loads(result.stdout), {"vpnUnits": expected, "dnsUnits": downloaders})

    def test_missing_or_invalid_declaration_fails_instead_of_skipping_units(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            for invalid in (None, {}, {"vpnUnits": []}, {"vpnUnits": ["unrelated.service"]},
                            {"vpnUnits": ["nzbget.service", "nzbget.service"]}):
                if invalid is not None:
                    path.write_text(json.dumps(invalid))
                result = subprocess.run([sys.executable, str(Path(__file__).with_name("media-vpn-leak-audit.py")),
                    "--config", str(path), "--list-services"], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
