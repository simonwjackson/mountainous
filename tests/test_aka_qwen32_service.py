import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
AKA_CONFIG = ROOT / "hosts" / "aka" / "default.nix"


class AkaQwen32ServiceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = AKA_CONFIG.read_text()

    def test_declares_vulkan_llama_cpp_service(self):
        self.assertIn("aka-llama-qwen32", self.config)
        self.assertIn("pkgs.llama-cpp.override", self.config)
        self.assertIn("vulkanSupport = true", self.config)
        self.assertIn("/bin/llama-server", self.config)
        self.assertIn("--device Vulkan0", self.config)
        self.assertIn("--gpu-layers all", self.config)

    def test_defaults_to_q4_with_q3_fallback(self):
        self.assertIn(
            "bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_S",
            self.config,
        )
        self.assertIn("Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:q3_k_m", self.config)
        self.assertIn("AKA_LLAMA_QWEN32_FALLBACK_MODEL", self.config)

    def test_service_is_on_demand_and_reuses_user_cache(self):
        service_start = self.config.index('systemd.services.aka-llama-qwen32')
        following_config = self.config[service_start:]
        next_top_level = re.search(r"\n  [a-zA-Z0-9_.-]+\s*=", following_config[1:])
        service_block = following_config if next_top_level is None else following_config[: next_top_level.start() + 1]

        self.assertNotIn("wantedBy", service_block)
        self.assertIn('User = "simonwjackson"', service_block)
        self.assertIn('HOME = "/home/simonwjackson"', service_block)
        self.assertIn('XDG_CACHE_HOME = "/home/simonwjackson/.cache"', service_block)
        self.assertRegex(
            service_block,
            r'SupplementaryGroups\s*=\s*\[\s*"render"\s*"video"\s*\];',
        )

    def test_does_not_open_broad_firewall_port(self):
        self.assertNotIn("allowedTCPPorts = [18080]", self.config)
        self.assertNotIn("allowedTCPPorts = [ 18080 ]", self.config)
        self.assertNotIn("allowedTCPPorts = [\n    18080", self.config)


if __name__ == "__main__":
    unittest.main()
