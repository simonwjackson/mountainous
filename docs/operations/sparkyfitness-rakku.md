# SparkyFitness placement on Rakku

Prepared only. Do not deploy until Simon approves the diff. Rakku never builds.
Use the reviewed commit in a checkout on Unzen, with a clean working tree:

```sh
NIX_SSHOPTS='-F /dev/null' nixos-rebuild switch --flake .#rakku --target-host simonwjackson@rakku --use-remote-sudo
```

## Network, state and memory

- Frontend: `127.0.0.1:4591` through nginx, not a default vhost.
- Tailnet name: `https://sparkyfitness.hummingbird-lake.ts.net`.
- Backend: port 3010. Upstream `SparkyFitnessServer.ts:946` uses
  `app.listen(PORT)`, which binds wildcard, not loopback. Rakku's IPv4/IPv6
  firewall adds an nftables input hook at priority -10 to reject non-loopback
  traffic to this port before both iptables and tailscaled's early ACCEPT.
  The existing iptables firewall stays enabled. The backend starts after the
  firewall and stops/restarts with it, so a failed guard cannot expose the API.
  Do not remove this guard.
- Persist `/var/lib/sparkyfitness` and `/var/lib/postgresql/16` under
  `/tundra/permafrost`. SparkyFitness UID/GID: 950/950, free in Rakku's passwd
  and group databases when prepared. PostgreSQL UID/GID: NixOS's fixed 71/71.
- Backend MemoryHigh/MemoryMax: 1G/1536M. PostgreSQL: 256M/512M. No other
  configured Rakku service uses PostgreSQL. Its live service was inactive.
  Large imports can hit these limits and fail; monitor before increasing them.
- PID 1 reads the root-owned 0400 sops environment template before switching
  to the backend or db-init user. Neither user needs direct file access.
- Logbook's layer, data, export bridge and persistence remain. Its two units
  have no boot targets and refuse explicit starts from the old app-only deploy
  controller. The sidecar no longer Wants the backend. Its secret templates
  cannot restart it. The Gadgetbridge path/service only exports a snapshot;
  it does not start either retired unit. The assistant's existing Logbook
  integration is unchanged and will not work while Logbook is retired.

## Owner account: a separate, approved two-step bootstrap

The pinned upstream has **no supported first-account bypass** while signup is
closed. `auth.ts:714` rejects every user creation before checking providers or
account count. `SparkyFitnessServer.ts:919-932` only promotes an existing
`SPARKY_FITNESS_ADMIN_EMAIL` account. There is no admin-password environment
variable or account-creation CLI. Do not insert users into PostgreSQL manually.

The prepared configuration always sets `SPARKY_FITNESS_DISABLE_SIGNUP=true`.
It cannot create the owner on first activation. A generated password is already
in sops as `sparkyfitness-owner-password`. Activation will install it root-only
on Rakku.

After the initial, separately approved deployment, use this short maintenance
window. It changes only runtime state, not the declarative closed-signup setting.
Only trusted local processes can access registration during the window.

1. On Rakku, mask and stop **only** `tsnet-proxy-sparkyfitness`, check the port
   3010 firewall rules, then temporarily enable signup for local registration.
   Do not stop nginx: it also serves Vela. Run in one root shell (`sudo -s`):

   ```sh
   set -euo pipefail
   systemctl mask --runtime --now tsnet-proxy-sparkyfitness.service
   /run/current-system/sw/bin/nft list chain inet sparkyfitness input
   # Confirm priority -10 and iifname != "lo" tcp dport 3010 reject.
   install -d /run/systemd/system/sparkyfitness.service.d
   bootstrap=/run/systemd/system/sparkyfitness.service.d/owner-bootstrap.conf
   trap 'rm -f "$bootstrap"; systemctl daemon-reload; systemctl restart sparkyfitness.service' EXIT
   printf '[Service]\nEnvironment=SPARKY_FITNESS_DISABLE_SIGNUP=false\n' > "$bootstrap"
   systemctl daemon-reload
   systemctl restart sparkyfitness.service
   # Wait for startup/migrations without sending or logging credentials.
   curl -fsS --retry 60 --retry-connrefused --retry-delay 2 \
     http://127.0.0.1:3010/api/auth/settings >/dev/null
   jq -n --rawfile password /run/secrets/sparkyfitness-owner-password \
     '{email:"simon.jackson@gmail.com",name:"Simon Jackson",password:($password|rtrimstr("\n"))}' \
     | curl -fsS http://127.0.0.1:3010/api/auth/sign-up/email \
       -H 'Content-Type: application/json' \
       -H 'Origin: https://sparkyfitness.hummingbird-lake.ts.net' \
       --data-binary @- --output /dev/null
   ```

   If registration fails, exit this shell. The trap closes signup again, and
   the tailnet proxy remains masked. Check whether the owner already exists
   before retrying; never delete an existing account as part of bootstrap.

2. In the same shell, remove the runtime override and restart the backend.
   This also promotes the owner's account to admin. Verify closure and the
   account before restoring the tailnet proxy:

   ```sh
   rm -f "$bootstrap"
   systemctl daemon-reload
   systemctl restart sparkyfitness.service
   curl -fsS --retry 60 --retry-connrefused --retry-delay 2 \
     http://127.0.0.1:3010/api/auth/settings | jq -e '.signup_disabled == true'
   sudo -u postgres psql sparkyfitness_db -c 'SELECT email, role FROM "user";'
   # Confirm exactly the intended owner exists and has role admin.
   trap - EXIT
   systemctl unmask --runtime tsnet-proxy-sparkyfitness.service
   systemctl start tsnet-proxy-sparkyfitness.service
   exit
   ```

Do not print the stored password or authentication responses. The owner can
retrieve the password from sops through an approved private channel.

## Post-deploy verification

From Unzen (after approval and deployment):

```sh
ssh -F /dev/null simonwjackson@rakku '
  readlink -f /run/current-system
  systemctl is-active sparkyfitness sparkyfitness-db-init postgresql nginx tsnet-proxy-sparkyfitness
  systemctl is-enabled logbook logbook-tsnet || true
  systemctl is-active logbook logbook-tsnet || true
  systemctl show logbook logbook-tsnet -p WantedBy -p RequiredBy -p RefuseManualStart
  systemctl show sparkyfitness postgresql -p MemoryHigh -p MemoryMax -p MemoryCurrent
  ss -ltn
  findmnt --target /var/lib/sparkyfitness
  findmnt --target /var/lib/postgresql/16
  getent passwd sparkyfitness postgres
  getent group sparkyfitness postgres
  sudo stat -c "%U:%G %a" /run/secrets/rendered/sparkyfitness.env
  sudo /run/current-system/sw/bin/nft list chain inet sparkyfitness input
  curl -fsS http://127.0.0.1:4591/ >/dev/null
  curl -fsS http://127.0.0.1:4591/api/auth/settings | jq -e ".signup_disabled == true"
  systemctl is-active home-assistant zwave-js
  curl -sS -o /dev/null -w "Home Assistant HTTP %{http_code}\n" http://127.0.0.1:8123/
'
curl -fsS https://sparkyfitness.hummingbird-lake.ts.net/ >/dev/null
curl -fsS https://sparkyfitness.hummingbird-lake.ts.net/api/auth/settings | jq -e '.signup_disabled == true'
# Direct backend access must fail, including through the trusted tailnet.
if curl --connect-timeout 3 -fsS http://rakku:3010/api/auth/settings; then
  echo 'ERROR: direct backend access is exposed' >&2
  exit 1
fi
```

Confirm nginx listens only at `127.0.0.1:4591` for this vhost, never port 80.
Confirm the two persistence mounts use `/tundra/permafrost`, and the generation
matches the reviewed build. Check the owner can sign in. Check Home Assistant's
Z-Wave integration in its UI; a running unit alone does not prove device health.
Do not reboot Rakku to verify this change.

## Rollback

From Unzen:

```sh
ssh -F /dev/null simonwjackson@rakku 'sudo nixos-rebuild switch --rollback'
```

If a bootstrap attempt is still in progress, first exit its root shell so the
trap removes the runtime signup override. Rollback changes the system generation,
not the new persisted database or uploads. Keep them for diagnosis. The previous
generation can start Logbook again; its data at `/var/lib/logbook` was not changed.
