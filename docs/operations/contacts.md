# Contacts CardDAV

The `contacts` service has one placement: Rakku. Its tailnet HTTPS name is
`contacts`; DAVx5 uses **https://contacts.hummingbird-lake.ts.net/**, login
**simon**, and the password below. HTTP listens only on `127.0.0.1:8480`.
The existing `tailnet-names` OAuth proxy forwards DAV methods, headers and bodies.
No LAN HTTP port or public listener is added.

## Before activation

Simon must add the **contacts-password** key with a nonempty, single-line UTF-8
password to the host's encrypted file, then commit the encrypted change:

```sh
./scripts/secrets secrets/hosts/rakku.yaml
```

This change only declares the secret; it does not set its value. Activation
fails until that key exists. Root decrypts it mode `0400`; `contacts.service`
loads a private copy through `LoadCredential`. `%d/contacts-password` is
`$CREDENTIALS_DIRECTORY/contacts-password`, not an environment password or a
Nix-store secret. Secret rotation restarts the server.

## Deploy and verify (operator only)

From a reviewed checkout containing the encrypted secret, build on an x86_64
builder and copy the system closure to Rakku. Do not build on Rakku and do not
use the disk-wiping installer.

```sh
NIX_SSHOPTS='-F /dev/null' nixos-rebuild switch --flake .#rakku --target-host root@rakku
ssh -F /dev/null root@rakku 'systemctl status contacts.service tsnet-proxy-contacts.service'
```

Wait for the `contacts` tailnet identity to join and obtain HTTPS through the
existing fleet OAuth mechanism. From a tailnet client, check discovery without
printing the password (`curl` prompts for it):

```sh
curl --user simon -i https://contacts.hummingbird-lake.ts.net/.well-known/carddav
```

Expect a redirect to `/principals/simon/`. Unauthenticated requests return 401.
In DAVx5 choose **Login with URL and user name**, enter the base URL above,
select **Contacts**, allow Android contact access, and sync a synthetic contact
before importing real data. DAVx5 on a phone has not been verified by this PR.

## First import

`serve` and `import` share an exclusive writer lock. Never import while the
server runs and never start another writer or proseQL runtime against this
state. Run these commands **on Rakku**, replacing `/path/to/export.vcf` with the
Google vCard export. The staged copy is readable only by the service account,
including when the original lives in a private home directory.

```sh
sudo systemctl stop contacts.service
sudo install -o contacts -g contacts -m 0600 /path/to/export.vcf /var/lib/contacts-import.vcf
sudo -u contacts /run/current-system/sw/bin/contacts import /var/lib/contacts-import.vcf --data-dir /var/lib/contacts
sudo rm -- /var/lib/contacts-import.vcf
sudo systemctl start contacts.service
```

If import fails, inspect its error before starting the server. An I/O failure
can leave an imported prefix; this is not a batch transaction. Repeating import
skips existing UIDs, but cards without UIDs get new UUIDs on every import.

## Service state and backups

`StateDirectory=contacts` creates `/var/lib/contacts`, mode `0700`, owned by the
system user `contacts`, with umask `0077`. A static user permits the stopped-unit
import above. Rakku persists UID/GID allocation in `/var/lib/nixos`. The feature
persists the whole state directory under `/tundra/permafrost`, so it survives
reboots and is included in full permafrost snapshots. The existing tailnet-names
layer persists `/var/lib/tsnet-proxy-contacts` there too.

No scheduled service-state backup convention exists in the current Nix modules.
Persistence is not an off-host backup. For a consistent, root-only backup on
Rakku, stop both units and archive application state and tailnet identity:

```sh
sudo systemctl stop tsnet-proxy-contacts.service contacts.service
sudo sh -c 'umask 077; tar --acls --xattrs --numeric-owner -czpf /root/contacts-state-$(date -u +%Y%m%dT%H%M%SZ).tar.gz -C /var/lib contacts tsnet-proxy-contacts'
sudo systemctl start contacts.service tsnet-proxy-contacts.service
```

Encrypt and copy the archive off-host, and test restoration before relying on
it. Back up `.contacts-format`, `contacts/`, `changes.jsonl`, and `sync-epoch`
together. Do not prune the unbounded sync log or add a format marker by hand.
Contact files and logs contain personal data. The server eagerly loads one book
and its unbounded history; monitor memory and disk use.

## Rollback and controlled move

Immediately after this deployment, roll the system back to the preceding
NixOS generation:

```sh
ssh -F /dev/null root@rakku 'systemctl stop tsnet-proxy-contacts.service contacts.service; nixos-rebuild switch --rollback'
```

Rollback stops the new service but does not delete its persisted state or the
new tailnet identity. Retain both for recovery; do not reset an epoch against
existing client sync tokens.

A controlled move needs explicit operator approval: stop the old placement,
back up and copy all service state and tailnet identity with private permissions,
update the sole placement, and only then start the destination. Never run two
placements, even against separate copies. Keep the stopped old state and system
generation as the rollback path. `checks.contacts` rejects a second placement,
a template/second writer, non-loopback HTTP, lost state persistence, or a missing
credential.
