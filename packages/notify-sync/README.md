# notify-sync

`notifyd` owns `org.freedesktop.Notifications`. SQLite stores notifications,
IDs, replay cursors, control de-duplication and the retry outbox together.
`notify-hub` handles Done buttons without a desktop and serves `/mcp` with
bearer authentication. Other hub HTTP paths proxy ntfy unchanged.

```
notify send --name builder --action logs=Logs "Build finished" "42 checks passed"
notify list --json
notify clear <seq>
notify wait --timeout 30s <seq>
```

Set `NOTIFY_URL`, `NOTIFY_TOKEN_FILE`, `NOTIFY_BUTTON_TOKEN_FILE`. Tokens are
read from files, not passed in argv. A button token must belong to the user
that can only write `notify-ctl`. App text in `list` is marked `untrusted`.
`wait` returns the first cached action or clear, including an event that
arrived between `send` and `wait`. Agents cannot invoke desktop app actions
through the CLI or MCP tools.

The view connects to `$XDG_RUNTIME_DIR/notify-sync/ui.sock`. Send one JSON
object per line: `subscribe`, `dismiss` with `id`, `action` with `id` and `key`,
or `dismiss_all`. The binding item and event schema is in the approved
contract and `types.go`. Subscribe returns a complete snapshot, including
`items: []` when empty. Slow readers disconnect and must resubscribe. Restart
snapshots do not create popups. Popup timeouts do not close stored items.

## Checks

```
NTFY_BIN=/path/to/ntfy NOTIFY_SEND=/path/to/notify-send go test -v ./...
go vet ./...
nix build .#notify-sync .#checks.x86_64-linux.notify-sync-vm \
  .#checks.x86_64-linux.notify-proxy .#checks.x86_64-linux.notify-server
```

The Go integration tests launch real ntfy and private D-Bus servers. Tests
skip those integrations when their executables are missing. The Nix package
supplies all executables, so none of those integrations skip in its check.
Run `gomod2nix --dir packages/notify-sync` after changing Go dependencies.

See `docs/decisions/notifications.md` for ordering, crash and scale limits.
