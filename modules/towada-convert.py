"""Convert the Towada disks from XFS to the bcachefs pool, one step at a time.

Every step checks its preconditions, writes a receipt under STATE, and refuses
to repeat or skip ahead. Nothing here forces an unmount.

  format ID...       create the pool on the configured member disks
  copy ID            copy one read-only XFS disk into the pool
  protect            keep the configured irreplaceable paths in two copies
  verify MANIFEST    check irreplaceable files against a SHA-256 manifest
  add ID             wipe a copied XFS disk and add it to the pool

Copy order matters when the same path exists on several disks: copy the
lowest-precedence disk first so the old mergerfs winner is written last.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("TOWADA_STATE", "/var/lib/towada-convert"))
CONFIG = json.loads(Path(os.environ["TOWADA_CONFIG"]).read_text())
POOL = CONFIG["mountPoint"]


def by_id(serial, part=""):
    return f"/dev/disk/by-id/{CONFIG['idPrefix']}{serial}{CONFIG['idSuffix']}{part}"


def run(*args, **kw):
    print("+", " ".join(args), flush=True)
    return subprocess.run(args, check=True, **kw)


def out(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def receipt(name):
    return STATE / f"{name}.json"


def write_receipt(name, data):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    data["at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    receipt(name).write_text(json.dumps(data, indent=2) + "\n")
    print(f"receipt: {receipt(name)}")


def need(name):
    if not receipt(name).exists():
        sys.exit(f"refusing: step '{name}' has no receipt")
    return json.loads(receipt(name).read_text())


def mounted(path):
    return subprocess.run(["mountpoint", "-q", path]).returncode == 0


def fstype(dev):
    return subprocess.run(
        ["blkid", "-p", "-o", "value", "-s", "TYPE", dev], capture_output=True, text=True
    ).stdout.strip()


def holders(dev):
    real = os.path.realpath(dev)
    found = []
    for line in Path("/proc/mounts").read_text().splitlines():
        source = line.split()[0]
        if source.startswith("/dev/") and os.path.realpath(source).startswith(real):
            found.append(line.split()[1])
    return found


def cmd_format(args):
    if receipt("format").exists():
        sys.exit("refusing: the pool was already formatted")
    ids = sorted(args.disks)
    if ids != sorted(CONFIG["members"]):
        sys.exit("refusing: format exactly the configured members: " + " ".join(sorted(CONFIG["members"])))
    if args.confirm != "wipe-" + "-".join(ids):
        sys.exit("refusing: pass --confirm wipe-" + "-".join(ids))
    devices = [by_id(CONFIG["members"][i]) for i in ids]
    for dev in devices:
        if not os.path.exists(dev):
            sys.exit(f"refusing: missing {dev}")
        if holders(dev):
            sys.exit(f"refusing: {dev} is mounted at {holders(dev)}")
    before = {dev: out("lsblk", "-no", "NAME,FSTYPE,SIZE,SERIAL", dev) for dev in devices}
    for dev in devices:
        run("wipefs", "--all", "--quiet", dev)
    labelled = []
    for disk, dev in zip(ids, devices):
        labelled += [f"--label={CONFIG['label']}.{disk}", dev]
    run(
        "bcachefs", "format",
        f"--data_replicas={CONFIG['dataReplicas']}",
        f"--metadata_replicas={CONFIG['metadataReplicas']}",
        f"--fs_label={CONFIG['label']}",
        f"--uuid={CONFIG['uuid']}",
        *labelled,
    )
    run("udevadm", "settle")
    uuid = out("blkid", "-p", "-o", "value", "-s", "UUID", devices[0])
    if uuid != CONFIG["uuid"]:
        sys.exit(f"formatted UUID {uuid} differs from the configured {CONFIG['uuid']}")
    write_receipt("format", {"members": {i: CONFIG["members"][i] for i in ids}, "uuid": uuid, "before": before})


def legacy_path(disk):
    return f"/srv/shores/towada/{disk}"


def cmd_copy(args):
    need("format")
    disk = args.disk
    if disk not in CONFIG["legacy"]:
        sys.exit(f"refusing: {disk} is not a legacy XFS disk")
    if not mounted(POOL):
        run("systemctl", "start", CONFIG["mountUnit"])
    src = legacy_path(disk)
    if not mounted(src):
        run("systemctl", "start", CONFIG["legacyUnits"][disk])
    if "ro" not in out("findmnt", "-no", "OPTIONS", src).split(","):
        sys.exit(f"refusing: {src} is not mounted read-only")
    excludes = [f"--exclude=/{e}" for e in CONFIG["copyExclude"]]
    run(
        "rsync", "-aHAX", "--numeric-ids", "--info=stats1,progress2",
        f"--groupmap={CONFIG['fromGid']}:{CONFIG['toGid']}",
        *excludes,
        f"{src}/", f"{POOL}/",
    )
    # A second pass must find nothing left to send, by size and time.
    pending = out(
        "rsync", "-aHAX", "--numeric-ids", "--dry-run", "--itemize-changes",
        f"--groupmap={CONFIG['fromGid']}:{CONFIG['toGid']}",
        *excludes, f"{src}/", f"{POOL}/",
    )
    left = [line for line in pending.splitlines() if line and not line.startswith(".d")]
    if left:
        sys.exit(f"copy incomplete: {len(left)} entries still differ; first: {left[0]}")
    files = sum(len(names) for _, _, names in os.walk(src))
    write_receipt(f"copy-{disk}", {"disk": disk, "serial": CONFIG["legacy"][disk], "files": files})


def effective_replicas(path):
    return out("getfattr", "--only-values", "-n", "bcachefs_effective.data_replicas", path)


def cmd_protect(args):
    need("format")
    for disk in CONFIG["legacy"]:
        need(f"copy-{disk}")
    paths = [Path(POOL) / rel for rel in CONFIG["twoCopies"]]
    missing = [str(p) for p in paths if not p.exists()]
    if missing:
        sys.exit("refusing: listed paths are absent from the pool: " + " ".join(missing))
    # Set on a directory, the option reaches every existing child and every
    # new file; reconcile then writes the second copies in the background.
    run("bcachefs", "set-file-option", "--data_replicas=2", *map(str, paths))
    run("bcachefs", "reconcile", "wait", POOL)
    wrong = []
    for path in paths:
        targets = [path] if path.is_file() else [path, *path.rglob("*")]
        wrong += [str(t) for t in targets if t.is_file() and effective_replicas(t) != "2"]
    if wrong:
        sys.exit(f"{len(wrong)} files lack two copies; first: {wrong[0]}")
    write_receipt("protect", {"paths": CONFIG["twoCopies"]})


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def cmd_verify(args):
    need("format")
    # Bytes, split on newline only: filenames may hold any byte except "/" and
    # NUL, including characters that str.splitlines() treats as line breaks.
    lines = [line for line in Path(args.manifest).read_bytes().split(b"\n") if line]
    bad, missing = [], []
    for line in lines:
        if line.startswith(b"\\"):
            # sha256sum escapes names holding a backslash or a newline.
            digest, rel = line[1:].split(b"  ", 1)
            rel = rel.replace(b"\\n", b"\n").replace(b"\\\\", b"\\")
        else:
            digest, rel = line.split(b"  ", 1)
        path = os.path.join(os.fsencode(POOL), rel)
        if not os.path.exists(path):
            missing.append(rel)
        elif sha256(path) != digest.decode():
            bad.append(rel)
    print(f"checked {len(lines)} files: {len(missing)} missing, {len(bad)} differ")
    for rel in (missing + bad)[:20]:
        print("  ", os.fsdecode(rel))
    if missing or bad:
        sys.exit(1)
    write_receipt("verify", {"manifest": args.manifest, "files": len(lines)})


def cmd_add(args):
    disk = args.disk
    serial = CONFIG["legacy"].get(disk)
    if serial is None:
        sys.exit(f"refusing: {disk} is not a legacy XFS disk")
    need(f"copy-{disk}")
    need("protect")
    need("verify")
    if receipt(f"add-{disk}").exists():
        sys.exit(f"refusing: {disk} was already added")
    if args.confirm != f"wipe-{serial}":
        sys.exit(f"refusing: pass --confirm wipe-{serial}")
    if not mounted(POOL):
        sys.exit("refusing: the pool is not mounted")
    # Every file already has its two copies on the existing members; adding a
    # disk only adds space. Record the pool state before the change.
    usage_before = out("bcachefs", "fs", "usage", POOL)
    src = legacy_path(disk)
    if mounted(src):
        run("systemctl", "stop", CONFIG["legacyUnits"][disk])
    dev = by_id(serial)
    if holders(dev):
        sys.exit(f"refusing: {dev} is still mounted at {holders(dev)}")
    if fstype(by_id(serial, "-part1")) != "xfs":
        sys.exit("refusing: expected the old XFS partition on " + dev)
    run("wipefs", "--all", "--quiet", by_id(serial, "-part1"))
    run("wipefs", "--all", "--quiet", dev)
    run("bcachefs", "device", "add", f"--label={CONFIG['label']}.{disk}", POOL, dev)
    write_receipt(f"add-{disk}", {"disk": disk, "serial": serial, "usageBefore": usage_before})


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("format")
    f.add_argument("disks", nargs="+")
    f.add_argument("--confirm", required=True)
    c = sub.add_parser("copy")
    c.add_argument("disk")
    sub.add_parser("protect")
    v = sub.add_parser("verify")
    v.add_argument("manifest")
    a = sub.add_parser("add")
    a.add_argument("disk")
    a.add_argument("--confirm", required=True)
    args = p.parse_args()
    if os.geteuid() != 0:
        sys.exit("run as root")
    {"format": cmd_format, "copy": cmd_copy, "protect": cmd_protect, "verify": cmd_verify,
     "add": cmd_add}[args.cmd](args)


if __name__ == "__main__":
    main()
