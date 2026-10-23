The alert comes from Beszel. Its title names the host.

Known normal states: myoko is a desktop that sleeps, and hiyori is a USB-stick
system that is usually unplugged, so "down" for either is normal. Say so in one
line and stop.

Steps:
1. Run `beszel list_systems` to see the whole fleet. More than one host down
   points at the network or at rakku, not at the host.
2. Run `beszel get_system '{"system":"<host>"}'` for the host in the title.
3. Look where the alert points:
   - "Connection ... is down": compare uptime and the last sample time.
   - "above threshold": `get_system_metrics` for 1h and 24h. Say whether it is
     a spike or a trend, and which service or container drives it.
   - "Failed services": `list_services` with state Failed, then
     `get_service_details` for each failed unit.
   - "SMART": `list_smart_devices` for the host. Name the disk and the
     attributes that changed.
   - Containers: `list_containers`, then `get_container_logs` for the
     unhealthy one.
4. Propose the next step Simon should take, with the exact command when you
   know it.
