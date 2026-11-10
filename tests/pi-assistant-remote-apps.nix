# Run the generated prepare script in a disposable home, not a fleet host.
{ flake, pkgs }:
let
  inherit (pkgs) lib;
  configured = flake.nixosConfigurations.rakku.config.mountainous.features.pi-assistant.mcpServers;
  torrents = {
    id = "torrents";
    title = "Torrents";
    url = "https://torrents-mcp.hummingbird-lake.ts.net/mcp";
  };
  offline = {
    title = "Offline module";
    url = "http://127.0.0.1:1/mcp";
  };
  instance =
    remoteApps:
    (flake.nixosConfigurations.rakku.extendModules {
      modules = [
        {
          mountainous.features.pi-assistant = {
            atlas = lib.mkForce null;
            groceries = lib.mkForce null;
            sharedSkills = lib.mkForce { };
            people.simon = {
              apps = lib.mkForce { };
              defaultViews = lib.mkForce { };
              extensions = lib.mkForce { };
              skills = lib.mkForce { };
              remoteApps = lib.mkForce remoteApps;
            };
          };
        }
      ];
    }).config.systemd.services.pi-assistant-simon.serviceConfig.ExecStartPre;
  remoteOnly = instance { inherit offline; };
  empty = instance { };
  expected = pkgs.writeText "remote-mcp-apps.json" (
    builtins.toJSON {
      servers = [ (offline // { id = "offline"; }) ];
    }
  );
in
assert builtins.elem torrents configured.simon;
assert lib.all (
  name: name == "simon" || lib.all (server: server.id != "torrents") configured.${name}
) (builtins.attrNames configured);
pkgs.runCommand "pi-assistant-remote-apps"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.gnused
    ];
  }
  ''
    export CREDENTIALS_DIRECTORY="$TMPDIR/credentials"
    mkdir -p "$CREDENTIALS_DIRECTORY"
    printf 'test-key' > "$CREDENTIALS_DIRECTORY/cliproxyapi-key"

    prepare() {
      # Relocate only the state declaration; execute the real generated script.
      sed "s|^state=/var/lib/pi-assistant-simon$|state=$TMPDIR/home|" "$1" > prepare.sh
      timeout 5 bash prepare.sh
    }

    # No local apps, Atlas, or launcher overrides: a remote alone writes a file.
    # Port 1 is unreachable in the sandbox. Waiting on it would time out here.
    prepare ${remoteOnly}
    diff -u ${expected} "$TMPDIR/home/mcp-apps.json"
    test "$(stat -c %a "$TMPDIR/home/mcp-apps.json")" = 600

    # Prepare overwrites stale configuration on every start.
    printf 'stale' > "$TMPDIR/home/mcp-apps.json"
    prepare ${remoteOnly}
    diff -u ${expected} "$TMPDIR/home/mcp-apps.json"

    # Removing the last remote restores the existing no-servers cleanup path.
    prepare ${empty}
    test ! -e "$TMPDIR/home/mcp-apps.json"
    touch "$out"
  ''
