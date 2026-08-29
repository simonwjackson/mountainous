# Azure SQL / WSL2 / Tailscale investigation

## Goal
Enable reliable access to `amazesql01.database.windows.net:1433` from local development, while keeping Tailscale working inside `aso` (NixOS on WSL2).

## What was tested

### Local app/API reverse tunnels
A local `autossh` setup was added to the former development command so these reverse forwards are created:

- `yuki:3000 -> local:3000`
- `yuki:3001 -> local:3001`
- `aso:3000 -> local:3000`
- `aso:3001 -> local:3001`

This is controlled locally via `.env.local` with:

```env
AMAZE_AUTOSSH_ENABLED=true
AMAZE_AUTOSSH_HOSTS=yuki,aso
```

Current implementation uses `src/core/scripts/dev-autossh-tunnels.sh` and `Procfile.min.dev`.

---

## Database forwarding investigation

### Initial idea
Tried to make `yuki:1433` forward to Azure SQL through SSH/autossh.

### What happened
Port `1433` on `yuki` could be bound by SSH reverse forwarding, but repeated attempts showed:

- listeners on `yuki:1433` were `sshd-session`
- `autossh` processes on `aso` were recreating the reverse forward
- this created conflicts and complexity

We later removed all DB forwarding logic and reverted to only the app/API tunnels on ports `3000` and `3001`.

---

## Direct connectivity findings

### From `aso`
Tested from `aso`:

- `amazesql01.database.windows.net:1433` -> reachable
- `amazesql01.privatelink.database.windows.net:1433` -> reachable
- `10.101.0.4:1433` -> reachable

TCP connectivity exists from `aso`.

### Authentication from `aso`
`sqlcmd` from `aso` failed because Azure authentication was not configured there:

- no usable `DefaultAzureCredential`
- no Azure CLI / azd / managed identity in place

So:
- network path from `aso` works
- Azure auth on `aso` does not

---

## Generation command findings
The former generation command ran locally and connected to SQL from the local machine using Azure AD token auth.

Even after creating a local tunnel through `aso`, the generation command still failed with:

> Connection was denied because Deny Public Network Access is set to Yes.

This means the connection path was still effectively hitting the public Azure SQL endpoint, which is blocked.

---

## Working local tunnel
This command worked:

```bash
ssh -N -L 1433:10.101.0.4:1433 aso
```

This confirms:
- `10.101.0.4` is the working private reachable target from `aso`
- tunneling through `aso` is the correct model

A local `/etc/hosts` override was also used:

```text
127.0.0.1 amazesql01.database.windows.net
```

That makes local clients connect to `127.0.0.1:1433` while still using the expected SQL hostname for TLS/name matching.

---

## DNS findings on `aso`
`aso` is NixOS on WSL2.

Current `/etc/resolv.conf` on `aso` showed:

```text
nameserver 100.100.100.100
```

That is Tailscale DNS.

Name resolution results on `aso`:

- `amazesql01.database.windows.net` -> `20.62.58.129`
- `amazesql01.privatelink.database.windows.net` -> `20.62.58.129`

Neither SQL hostname currently resolves to the private IP from within `aso`.

Reverse lookup for `10.101.0.4` returned no useful hostname.

Conclusion:
- `aso` can reach the private SQL IP directly
- but `aso` does not currently resolve a stable hostname to that private IP
- therefore the raw IP works, but DNS does not yet provide a durable name

---

## Constraint: Tailscale vs Azure VPN
A proposed approach was to let WSL inherit Windows DNS, but that was rejected because:

- Tailscale on Windows cannot coexist with Azure VPN in the required way

Therefore:
- Tailscale must remain inside WSL
- but WSL still needs Azure/VPN-related DNS resolution too

---

## Recommended architecture
Implement **split DNS inside `aso`**.

### Why
Need both:
- Tailscale/MagicDNS resolution
- Azure/private DNS resolution

### Desired behavior
Inside `aso`:
- `*.ts.net` and tailnet names -> resolve via Tailscale DNS (`100.100.100.100`)
- Azure/private names -> resolve via Windows/VPN DNS or another resolver that knows private Azure zones

### Recommended implementation
Use a local split-DNS resolver inside WSL, e.g.:
- `dnsmasq`, or
- `systemd-resolved`

Suggested model:
- disable Tailscale DNS takeover in WSL:

```bash
sudo tailscale set --accept-dns=false
```

- then route:
  - `ts.net` / tailnet domain -> `100.100.100.100`
  - `privatelink.database.windows.net` and other Azure-private zones -> VPN-aware upstream
  - default queries -> VPN-aware upstream

This would allow a durable tunnel command like:

```bash
ssh -N -L 1433:amazesql01.privatelink.database.windows.net:1433 aso
```

instead of hardcoding:

```bash
ssh -N -L 1433:10.101.0.4:1433 aso
```

---

## Short-term practical option
If split DNS is not set up yet, continue using the working IP-based tunnel:

```bash
ssh -N -L 1433:10.101.0.4:1433 aso
```

with local `/etc/hosts`:

```text
127.0.0.1 amazesql01.database.windows.net
```

This works, but it depends on the private IP staying unchanged.

---

## Final recommendation
### Immediate
Use:

```bash
ssh -N -L 1433:10.101.0.4:1433 aso
```

### Medium term
Set up split DNS inside `aso` so that:
- Tailscale names still resolve
- Azure private names resolve automatically
- the tunnel can target a hostname instead of a raw IP

### Keep in repo
Keep the current development tunnel behavior only for:
- `3000`
- `3001`

No DB forwarding logic should remain in the dev Procfile flow.
