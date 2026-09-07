"""Import-only, fixed Korri/Sunshine maintenance filter; never a cutover CLI.

The caller must exclude concurrent privileged firewall writers. Nothing removes
rules on exception, object disposal, or process exit. Receipts are process-local:
losing one leaves an unowned collision for manual review, never automatic adoption.
Persistent systemd gates, NOT this kernel table, provide reboot safety.
"""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import subprocess

TABLE = "korri_maintenance_isolation"
RULES_FILE = Path(__file__).with_suffix(".nft")


class Refusal(RuntimeError):
    """Do not advance or release persistent gates; table presence is not assured."""


class RemovalUncertain(Refusal):
    """Deletion may have committed; only the supervisor can resolve release."""


@dataclass(frozen=True)
class _InstalledTable:
    boot: str
    namespace: tuple[int, int]
    handle: int
    contents: str


def _context():
    namespace = Path("/proc/self/ns/net").stat()
    return (
        Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
        (namespace.st_dev, namespace.st_ino),
    )


def _objects(output):
    """Read nft's published JSON envelope, excluding version-only metadata."""
    try:
        objects = json.loads(output)["nftables"]
        if not isinstance(objects, list):
            raise ValueError("not an object list")
        result = []
        for item in objects:
            if not isinstance(item, dict) or len(item) != 1:
                raise ValueError("ambiguous object")
            if "metainfo" not in item:
                result.append(item)
        return result
    except (KeyError, ValueError, TypeError) as error:
        raise Refusal(
            "invalid nft evidence; keep separate persistent gates in place"
        ) from error


def _table_handle(objects):
    tables = [item["table"] for item in objects if "table" in item]
    if len(tables) != 1:
        raise Refusal("expected exactly one table in nft evidence")
    table = tables[0]
    if (
        table.get("family") != "inet"
        or table.get("name") != TABLE
        or type(table.get("handle")) is not int
        or table["handle"] <= 0
    ):
        raise Refusal("wrong table identity in nft evidence")
    return table["handle"]


class NetworkIsolation:
    """Install, verify, explicitly remove one exact owned table.

    The immutable module, adjacent rules file, and nft executable must be rooted
    Nix store artifacts. This object never adopts an existing table. Removal
    checks boot, network namespace, all objects/handles, then deletes by handle
    rather than name. No default policies or other tables are changed.
    """

    def __init__(self, nft):
        self.nft = str(Path(nft).resolve(strict=True))
        self._installed = None

    def _preflight(self):
        if os.geteuid() != 0:
            raise Refusal("network isolation requires the independent root caller")
        for path in (Path(self.nft), Path(__file__), RULES_FILE):
            resolved = path.resolve(strict=True)
            info = resolved.stat()
            if (
                not str(resolved).startswith("/nix/store/")
                or not resolved.is_file()
                or info.st_uid != 0
                or info.st_mode & 0o222
            ):
                raise Refusal("root the immutable module, rules, and nft executable")

    def _run(self, *arguments, contents=None):
        try:
            result = subprocess.run(
                [self.nft, *arguments],
                input=contents,
                text=True,
                capture_output=True,
                timeout=15,
                check=True,
            )
        except (OSError, subprocess.SubprocessError) as error:
            # A timeout can mean the atomic transaction committed. Never infer
            # absence or delete anything to compensate for an unknown result.
            raise Refusal(
                "nft failed or result unknown; do not advance; "
                "keep separate persistent gates in place and require supervisor inspection"
            ) from error
        return result.stdout

    def _snapshot(self):
        objects = _objects(self._run("-j", "-a", "-n", "list", "table", "inet", TABLE))
        handle = _table_handle(objects)
        return handle, json.dumps(objects, sort_keys=True, separators=(",", ":"))

    def install(self):
        """One exclusive kernel transaction; any collision/failure leaves evidence."""
        self._preflight()
        if self._installed is not None:
            raise Refusal("this caller already holds a table receipt")
        boot, namespace = _context()
        events = _objects(self._run("-j", "-e", "-n", "-f", str(RULES_FILE)))
        # --echo gives the handle created by this transaction. A later same-name
        # table must never become ours merely because a subsequent list sees it.
        created = [item.get("add", item.get("create", item)) for item in events]
        handle = _table_handle(created)
        actual_handle, contents = self._snapshot()
        if handle != actual_handle or (boot, namespace) != _context():
            raise Refusal("table/context changed after install; retain evidence")
        self._installed = _InstalledTable(boot, namespace, handle, contents)
        self.verify()

    def verify(self):
        """Refuse absent, replaced, altered, foreign-namespace or prior-boot state."""
        self._preflight()
        receipt = self._installed
        if receipt is None:
            raise Refusal("no owned table receipt; never adopt")
        if (receipt.boot, receipt.namespace) != _context():
            raise Refusal("receipt belongs to another boot or network namespace")
        if self._snapshot() != (receipt.handle, receipt.contents):
            raise Refusal("owned table changed; do not delete foreign contents")

    def remove(self):
        """Explicit release; an uncertain result preserves the receipt, not the table.

        The caller must already have proved release safe. A stale receipt cannot
        make a retry succeed after deletion committed. No compensation or adoption
        resolves this ambiguity; keep persistent gates for supervisor inspection.
        """
        self.verify()
        receipt = self._installed
        try:
            self._run(
                "-f", "-", contents=f"delete table inet handle {receipt.handle}\n"
            )
            tables = _objects(self._run("-j", "list", "tables", "inet"))
        except Refusal as error:
            raise RemovalUncertain(
                "removal failed or result unknown; table may already be absent; "
                "keep separate persistent gates in place and require supervisor inspection"
            ) from error
        if any(item.get("table", {}).get("name") == TABLE for item in tables):
            raise Refusal("table name replaced during removal; leave replacement")
        self._installed = None
