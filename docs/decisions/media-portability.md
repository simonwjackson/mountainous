# Controlled media-service moves with local staging

Accepted by the operator on 2026-10-10. Media applications must support separate host placement without resetting application configuration or manually reconfiguring their clients. Unzen is the first target, not a permanent co-location requirement.

Use controlled moves, not automatic failover. Each move preserves service addresses, application state, credentials, and network identity. Only one host owns the active service during the handoff.

Keep staging on the downloader's current host. Other applications receive managed access to its completed files. A downloader move includes its work files. Long-term media remains on Zao for this port.

## Trade-offs

| Chosen policy | Rejected alternative | Cost |
| --- | --- | --- |
| Controlled moves preserve state through an explicit handoff. | Automatic failover requires storage recovery and competing-owner controls. | The moved service pauses during the handoff. |
| Local staging keeps downloading and unpacking on the downloader host's disk. | Shared staging avoids copying work files when compute moves. | Downloader moves consume transfer time and bandwidth. Remote ARR access needs managed storage access. |
| Stable service endpoints work across host placement. | Local-only application connections assume co-location. | Cross-host network failures can interrupt imports. |

Service identities need OAuth-backed tagged enrollment with routine node-key expiry disabled. Cairn's existing host registration provides a pattern, not an implemented replacement for the legacy service proxies. OAuth credentials remain revocable.

Approval of this design does not authorize live cutover, bulk data transfer, credential replacement, download resumption, forced imports, or deletion of existing state or media. See the [implementation and acceptance plan](../plans/media-portability.md).
