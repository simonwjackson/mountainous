import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class SecretsRekeyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build = subprocess.run(
            ["nix", "build", ".#secrets", "--no-link", "--print-out-paths"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        cls.secrets = pathlib.Path(build.stdout.strip()) / "bin" / "secrets"

        rage_build = subprocess.run(
            ["nix", "build", "nixpkgs#rage", "--no-link", "--print-out-paths"],
            check=True,
            capture_output=True,
            text=True,
        )
        cls.rage = pathlib.Path(rage_build.stdout.strip()) / "bin" / "rage"

    def run_rekey(self, cwd, home, *args):
        env = os.environ.copy()
        env["HOME"] = str(home)
        return subprocess.run(
            [self.secrets, "rekey", *args],
            cwd=cwd,
            env=env,
            capture_output=True,
            text=True,
        )

    def test_help_describes_identity_discovery(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = pathlib.Path(temp_dir)
            result = self.run_rekey(temp, temp, "--help")

        self.assertEqual(result.returncode, 0)
        self.assertIn("probes readable user and host SSH", result.stdout)

    def test_rejects_a_directory_outside_a_git_repository(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = pathlib.Path(temp_dir)
            result = self.run_rekey(temp, temp)

        self.assertEqual(result.returncode, 1)
        self.assertIn("Not inside a git repository", result.stderr)

    def test_rejects_a_repository_without_secret_rules(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = pathlib.Path(temp_dir)
            repo = temp / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", "--quiet"], cwd=repo, check=True)

            result = self.run_rekey(repo, temp / "home")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Secrets rules not found", result.stderr)

    def test_rekeys_from_a_nested_repository_directory(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = pathlib.Path(temp_dir)
            repo = temp / "repo"
            secrets_dir = repo / "secrets"
            secrets_dir.mkdir(parents=True)
            subprocess.run(["git", "init", "--quiet"], cwd=repo, check=True)

            home = temp / "home"
            ssh_dir = home / ".ssh"
            ssh_dir.mkdir(parents=True)
            identity = ssh_dir / "id_ed25519"
            subprocess.run(
                [
                    "ssh-keygen",
                    "-q",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    str(identity),
                ],
                check=True,
            )
            public_key = identity.with_suffix(".pub").read_text().strip()

            rules = secrets_dir / "default.nix"
            rules.write_text(
                '{ "secrets/example.age".publicKeys = [ '
                f'"{public_key}" ]; }}\n'
            )
            secret = secrets_dir / "example.age"
            subprocess.run(
                [self.rage, "-e", "-r", public_key, "-o", secret],
                input="secret-value",
                text=True,
                check=True,
            )

            nested = repo / "nested" / "directory"
            nested.mkdir(parents=True)
            result = self.run_rekey(nested, home)
            decrypted = subprocess.run(
                [self.rage, "-d", "-i", identity, secret],
                check=True,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(decrypted.stdout, "secret-value")


if __name__ == "__main__":
    unittest.main()
