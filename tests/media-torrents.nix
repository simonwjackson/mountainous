# Production unit contracts plus real settings merge and daemon RPC admission.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  c = self.nixosConfigurations.unzen.config;
  service = c.systemd.services.torrents;
  transmission = c.systemd.services.transmission;
  proxy = c.systemd.services.tsnet-proxy-torrents;
  secret = c.sops.secrets.transmission-rpc-password;
  credential = "transmission-rpc-password:${secret.path}";
in
assert c.users.users.torrents.isSystemUser;
assert service.serviceConfig.User == "torrents";
assert service.serviceConfig.Group == "media" && c.users.users.torrents.group == "media";
assert service.environment.PORT == "3190" && service.environment.HOST == "127.0.0.1";
assert service.environment.TORRENTS_ROOT == "/srv/basin/manual";
assert service.environment.TRANSMISSION_URL == "http://10.200.200.2:9091/transmission/rpc";
assert service.environment.TRANSMISSION_USER == "torrents";
assert service.environment.TORRENTS_PEOPLE == "simon";
assert lib.hasInfix "torrents-mcp.hummingbird-lake.ts.net"
  service.environment.TORRENTS_ALLOWED_HOSTS;
assert lib.hasSuffix "/bin/torrents" service.serviceConfig.ExecStart;
assert lib.all (unit: builtins.elem unit service.after) [
  "media-vpn.service"
  "transmission.service"
];
assert !(service.serviceConfig ? NetworkNamespacePath);
assert service.serviceConfig.ProtectSystem == "strict";
assert service.serviceConfig.NoNewPrivileges;
assert builtins.elem "/srv/basin/manual" service.serviceConfig.ReadOnlyPaths;
assert service.serviceConfig.ReadWritePaths or [ ] == [ ];
assert builtins.elem credential service.serviceConfig.LoadCredential;
assert builtins.elem credential transmission.serviceConfig.LoadCredential;
assert secret.owner == "root" && secret.group == "root" && secret.mode == "0400";
assert lib.hasSuffix "/secrets/hosts/unzen.yaml" (toString secret.sopsFile);
assert lib.all (unit: builtins.elem unit secret.restartUnits) [
  "transmission.service"
  "torrents.service"
];
assert c.services.transmission.package.version == "4.1.4";
assert builtins.length transmission.serviceConfig.ExecStartPre == 2;
assert lib.hasInfix "media-state-ready.py transmission" (
  builtins.head transmission.serviceConfig.ExecStartPre
);
assert lib.hasInfix
  "media-transmission-auth.py /var/lib/transmission/.config/transmission-daemon/settings.json"
  (builtins.elemAt transmission.serviceConfig.ExecStartPre 1);
assert lib.all (path: builtins.elem path transmission.serviceConfig.BindPaths) [
  "/srv/basin/downloads/torrents"
  "/srv/basin/manual"
];
assert builtins.elem "d /srv/basin/manual 2775 transmission media -" c.systemd.tmpfiles.rules;
assert lib.hasInfix "-hostname torrents-mcp" proxy.serviceConfig.ExecStart;
assert lib.hasInfix "-backend http://127.0.0.1:3190 -port 443" proxy.serviceConfig.ExecStart;
assert !(proxy.unitConfig ? ConditionPathExists) && !(proxy.unitConfig ? ConditionFileNotEmpty);
assert builtins.length proxy.serviceConfig.LoadCredential == 2;
assert proxy.serviceConfig.StateDirectory == "tsnet-proxy-torrents";
assert lib.hasInfix "-hostname torrents "
  c.systemd.services.tsnet-proxy-transmission.serviceConfig.ExecStart;
pkgs.runCommand "media-torrents" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${./media-transmission-auth.py} ${../modules/media-transmission-auth.py}
  python3 ${./media-transmission-rpc.py} ${../modules/media-transmission-auth.py} ${c.services.transmission.package}/bin/transmission-daemon
  touch "$out"
''
