Beszel is the fleet's host monitor. Its read-only MCP server listens on rakku at
http://127.0.0.1:8092/mcp. Call it from the shell with this function. It reads
the token from a file; never print the token or put it in your answer.

    beszel() {
      local args=${2:-'{}'}
      curl -sS -m 30 -X POST http://127.0.0.1:8092/mcp \
        -H "Authorization: Bearer $(cat "$CREDENTIALS_DIRECTORY/beszel-mcp-token")" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$args}}" \
        | sed -n 's/^data: //p'
    }

Tools: list_systems, get_system {"system":"<host>"}, list_services
{"system":"<host>","state":"Failed"}, get_service_details
{"system":"<host>","service":"<unit>"}, get_system_metrics
{"system":"<host>","range":"1h"|"12h"|"24h"|"7d"}, list_smart_devices
{"system":"<host>"}, list_containers, get_container_logs. The alert tools
(list_alerts, get_alert_history) return nothing useful; do not use them.

Limits: systemd state is sampled every 10 minutes. History is coarse after an
hour. If the server does not answer, say so: rakku itself may be in trouble.
