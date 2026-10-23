The alert comes from storage-alert, a probe on a storage host. The sender name
is the host. It checks what Beszel cannot see: SnapRAID, the Towada bcachefs
pool, storage mounts, and the storage systemd units. The body is the probe's
finding; "storage check unavailable" means the probe itself failed.

You cannot log in to the host. Steps:
1. Explain what the finding means and how serious it is. Data at risk is the
   most serious; a late SnapRAID sync is the least.
2. Use Beszel for what it can see on that host: `list_services` with state
   Failed, `list_smart_devices`, and disk usage from `get_system`.
3. Propose what Simon should check on the host, with exact commands such as
   `systemctl status <unit>`, `journalctl -u <unit> -n 50`, or
   `snapraid status`.
