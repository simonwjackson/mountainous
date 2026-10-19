import json

start_all()
machine.wait_for_unit("multi-user.target")
machine.fail("mountpoint -q /srv/lakes/towada")
machine.fail("towada-storage admit")
machine.fail("systemctl is-active nfs-server.service")
machine.fail("systemctl is-active jellyfin.service")
machine.succeed("test ! -d /srv/lakes/towada/media")
# Repeated resolver regeneration must not restart the non-caching proxy.
machine.wait_for_unit("nscd.service")
pid = machine.succeed("systemctl show -p MainPID --value nscd.service").strip()
machine.succeed(
    "for i in $(seq 1 12); do printf 'nameserver 192.0.2.%s\\n' $i | resolvconf -a fixture; done; resolvconf -d fixture"
)
assert machine.succeed("systemctl show -p MainPID --value nscd.service").strip() == pid
# The non-restarting proxy must still pick up changed resolver data.
for address, answer in [("127.0.0.2", "192.0.2.10"), ("127.0.0.3", "192.0.2.20")]:
    machine.succeed(
        f"dnsmasq --keep-in-foreground --no-resolv --no-hosts --bind-interfaces --listen-address={address} --address=/storage.test/{answer} --pid-file= >/tmp/dns-{answer}.log 2>&1 &"
    )
    machine.succeed(f"printf 'nameserver {address}\\n' | resolvconf -x -a lo.fixture")
    machine.wait_until_succeeds(f"getent ahostsv4 storage.test | grep -q {answer}")
assert machine.succeed("systemctl show -p MainPID --value nscd.service").strip() == pid
machine.succeed("resolvconf -d lo.fixture; pkill -x dnsmasq")


for disk in ["vdb", "vdc", "vdd", "vde"]:
    machine.succeed(
        f"parted -s /dev/{disk} mklabel gpt mkpart primary 1MiB 100%; udevadm settle; mkfs.xfs -f /dev/{disk}1"
    )
machine.succeed("udevadm trigger; udevadm settle; systemctl reset-failed")
machine.succeed("systemctl start srv-range-media-tv.mount srv-range-media-movies.mount")
machine.succeed("systemctl start nfs-server.service jellyfin.service")
machine.succeed("towada-storage admit")
# Metadata/lease/interruption contracts require a real supported filesystem,
# not the Nix builder's /build (which may not support xattrs).
machine.succeed(
    "TMPDIR=/srv/cache/towada python3 -m unittest discover -s /etc/disk-array-tests/tests -p test_disk_array_mover.py"
)
# Reproduce the original self-copy topology using the real mergerfs mount.
machine.succeed("printf original > /srv/cache/towada/self-copy")
machine.succeed(
    "rsync -a --remove-source-files /srv/cache/towada/self-copy /srv/lakes/towada/"
)
# The baseline rsync path returned success and removed the only backing file.
machine.fail("test -e /srv/cache/towada/self-copy")
machine.fail("test -e /srv/shores/towada/00/self-copy")
machine.fail("test -e /srv/shores/towada/01/self-copy")
machine.succeed("printf original > /srv/cache/towada/self-copy")
config_path = machine.succeed(
    "sed -n 's/.*--config \\([^ ]*\\).*/\\1/p' $(readlink -f $(command -v towada-storage))"
).strip()
config = json.loads(machine.succeed(f"cat {config_path}"))
config["mounts"][0]["path"] = "/srv/lakes/towada"
machine.succeed("cat > /tmp/union.json <<'EOF'\n" + json.dumps(config) + "\nEOF")
module = machine.succeed(
    "sed -n 's/.*python3 \\([^ ]*\\).*/\\1/p' $(readlink -f $(command -v towada-storage))"
).strip()
machine.fail(f"python3 {module} --config /tmp/union.json copy --batch union")
machine.succeed("test -f /srv/cache/towada/self-copy")
wrong_identity = json.loads(machine.succeed(f"cat {config_path}"))
wrong_identity["mounts"][2]["uuid"] = "wrong-parity-uuid"
machine.succeed(
    "cat > /tmp/wrong-identity.json <<'EOF'\n" + json.dumps(wrong_identity) + "\nEOF"
)
machine.fail(f"python3 {module} --config /tmp/wrong-identity.json admit")
wrong_identity = json.loads(machine.succeed(f"cat {config_path}"))
wrong_identity["mounts"][-1]["fsRoot"] = "/not-cache"
machine.succeed(
    "cat > /tmp/wrong-cache.json <<'EOF'\n" + json.dumps(wrong_identity) + "\nEOF"
)
machine.fail(f"python3 {module} --config /tmp/wrong-cache.json admit")

machine.succeed("printf identity > /srv/cache/towada/media/tv/identity")
client.wait_for_unit("multi-user.target")
client.succeed(
    "mkdir -p /mnt/media /mnt/view; mount -t nfs -o vers=4.2,actimeo=0 machine:/ /mnt/media; bindfs /mnt/media/tv /mnt/view"
)
client.succeed("test $(cat /mnt/view/identity) = identity; ls /mnt/view")
dir_inode = machine.succeed("stat -c %i /srv/lakes/towada/media/tv").strip()
file_inode = machine.succeed("stat -c %i /srv/lakes/towada/media/tv/identity").strip()
machine.succeed("towada-storage copy --batch first --target 00")
machine.succeed(
    "test -f /srv/cache/towada/self-copy; cmp /srv/cache/towada/self-copy /srv/shores/towada/00/self-copy"
)
machine.fail("towada-storage release --quiesced --batch first")
machine.succeed("towada-storage resume --batch first")
machine.succeed("towada-storage protect --batch first")
machine.fail("towada-storage release --batch first")
machine.succeed("towada-storage release --quiesced --batch first")
machine.fail("test -e /srv/cache/towada/self-copy")
status = json.loads(machine.succeed("cat /var/lib/disk-array/towada/status.json"))
assert status["pendingFiles"] is None and status["pendingBytes"] is None
assert status["releasedFiles"] == 2
machine.succeed(
    "test $(stat -c %a /var/lib/disk-array/towada/status.json) = 644; test $(stat -c %a /var/lib/disk-array/towada/receipts) = 700"
)
machine.succeed(
    "test -f /srv/shores/towada/00/self-copy; test -d /srv/cache/towada/media/tv"
)
assert machine.succeed("stat -c %i /srv/lakes/towada/media/tv").strip() == dir_inode
assert (
    machine.succeed("stat -c %i /srv/lakes/towada/media/tv/identity").strip()
    != file_inode
)
# Directory identity is preserved, but the default hybrid-hash changes file
# identity at branch handoff. Do NOT infer safe online release from a good hash.
print(
    "NFS after branch handoff:",
    client.execute("timeout 5 cat /mnt/view/identity; timeout 5 ls /mnt/view"),
)
client.succeed("umount /mnt/view; umount /mnt/media")
machine.succeed(
    "systemctl stop nfs-server.service jellyfin.service media-tiering-movies-mount.service media-tiering-tv-mount.service srv-range-media-tv.mount srv-range-media-movies.mount; systemctl restart srv-lakes-towada.mount; systemctl start nfs-server.service"
)
assert machine.succeed("stat -c %i /srv/lakes/towada/media/tv").strip() == dir_inode
client.succeed(
    "mount -t nfs -o vers=4.2,actimeo=0 machine:/ /mnt/media; bindfs /mnt/media/tv /mnt/view; test $(cat /mnt/view/identity) = identity; ls /mnt/view; umount /mnt/view; umount /mnt/media"
)

# Hidden files and excluded paths cannot be called protected.
machine.succeed(
    "printf secret > /srv/cache/towada/.secret; printf partial > /srv/cache/towada/file.tmp"
)
plan = json.loads(machine.succeed("towada-storage plan"))
assert plan["candidates"] == []
machine.succeed("test -f /srv/cache/towada/.secret; test -f /srv/cache/towada/file.tmp")

# Same-name conflicts retain both files. Identical destinations can be adopted.
machine.succeed(
    "printf source > /srv/cache/towada/conflict; printf other > /srv/shores/towada/00/conflict"
)
machine.fail("towada-storage copy --batch conflict --target 00")
machine.succeed(
    "test $(cat /srv/cache/towada/conflict) = source; test $(cat /srv/shores/towada/00/conflict) = other"
)
machine.succeed(
    "rm /srv/shores/towada/00/conflict; towada-storage resume --batch conflict --target 00"
)
machine.succeed("towada-storage copy --batch adopt --target 00")

# Source mutation cannot be released even after successful protection.
machine.succeed("towada-storage protect --batch conflict")
# A real subprocess failure after diff must invalidate every old receipt before
# sync could write parity. The wrapper is a configurable process fixture, not
# an alternate mover implementation.
original_config = json.loads(machine.succeed(f"cat {config_path}"))
runner = (
    '#!/bin/sh\ncase "$3" in diff) exec '
    + original_config["snapraid"]
    + ' "$@";; sync) exit 42;; *) exit 43;; esac\n'
)
machine.succeed(
    "cat > /tmp/sync-failure <<'EOF'\n" + runner + "EOF\nchmod +x /tmp/sync-failure"
)
failed_config = dict(original_config)
failed_config["snapraid"] = "/tmp/sync-failure"
machine.succeed(
    "cat > /tmp/sync-failure.json <<'EOF'\n" + json.dumps(failed_config) + "\nEOF"
)
machine.fail(f"python3 {module} --config /tmp/sync-failure.json sync")
machine.fail("towada-storage release --quiesced --batch conflict")
machine.succeed("test -f /srv/cache/towada/conflict")
machine.succeed("towada-storage protect --batch conflict")
machine.succeed("printf changed >> /srv/cache/towada/conflict")
machine.fail("towada-storage release --quiesced --batch conflict")
machine.succeed("test -f /srv/cache/towada/conflict")

# A later sync attempt invalidates protected batches even if interrupted/failing.
# Diff failures must not become zero removals. Delete one protected test file.
machine.succeed("rm /srv/shores/towada/00/self-copy")
machine.fail("towada-storage sync")
machine.succeed("test -f /srv/cache/towada/conflict")

# Shared flock excludes all commands, not only movers.
machine.succeed("flock /run/lock/disk-array-towada.lock sleep 60 >/tmp/lock-log 2>&1 &")
machine.wait_until_fails("flock -n /run/lock/disk-array-towada.lock true")
for command in [
    "copy --batch locked",
    "protect --batch adopt",
    "release --batch adopt",
    "sync",
    "scrub",
]:
    machine.fail("towada-storage " + command)
machine.succeed("pkill -x sleep")

# No missing data/parity root may be accepted as an empty directory. Stop only
# fixture units; this test never unplugs or accesses a production enclosure.
for disk in ["02", "00"]:
    machine.succeed(f"systemctl stop srv-shores-towada-{disk}.mount")
    machine.fail("mountpoint -q /srv/lakes/towada")
    machine.fail("systemctl is-active nfs-server.service")
    machine.fail("systemctl is-active jellyfin.service")
    for command in ["admit", "copy --batch absent", "sync", "scrub"]:
        machine.fail("towada-storage " + command)
    machine.succeed("systemctl reset-failed; systemctl start srv-lakes-towada.mount")

machine.succeed("mv /srv/cache/towada/conflict /srv/cache/towada/.retained-conflict")

# Full destination retains original and leaves an inspectable temporary copy.
machine.succeed(
    "dd if=/dev/zero of=/srv/shores/towada/01/fill bs=1M status=none || true"
)
machine.succeed("dd if=/dev/zero of=/srv/cache/towada/enospc bs=1M count=8 status=none")
machine.fail("towada-storage copy --batch enospc --target 01")
machine.succeed("test -f /srv/cache/towada/enospc")

# Aged files are staged even when the shared cache filesystem is below 80%.
age_config = json.loads(machine.succeed(f"cat {config_path}"))
age_config["ageMinutes"] = 1440
machine.succeed("cat > /tmp/aged.json <<'EOF'\n" + json.dumps(age_config) + "\nEOF")
machine.succeed(
    "printf aged > /srv/cache/towada/aged; touch -d '2 days ago' /srv/cache/towada/aged; test $(df --output=pcent /srv/cache/towada | tail -1 | tr -dc 0-9) -lt 80"
)
first_batch = machine.succeed(
    f"python3 {module} --config /tmp/aged.json scheduled --limit 1"
).strip()
second_batch = machine.succeed(
    f"python3 {module} --config /tmp/aged.json scheduled --limit 1"
).strip()
assert first_batch == second_batch
machine.succeed(
    "test -f /srv/cache/towada/aged; cmp /srv/cache/towada/aged /srv/shores/towada/00/aged"
)
status = json.loads(machine.succeed("cat /var/lib/disk-array/towada/status.json"))
assert (
    status["phase"] == "scheduled-complete"
    and status["protectedFiles"] is None
    and status["releasedFiles"] == 0
)
