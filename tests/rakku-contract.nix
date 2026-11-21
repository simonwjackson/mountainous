# Deployment gates for the real evaluated host, not a duplicate module fixture.
c:
let
  persistence = c.environment.persistence."/tundra/permafrost";
  directories = map (
    entry: if builtins.isString entry then entry else entry.directory
  ) persistence.directories;
  ha = c.virtualisation.oci-containers.containers.home-assistant;
  haExec = c.systemd.services.home-assistant.script;
  zwaveExec = c.systemd.services.zwave-js.serviceConfig.ExecStart;
in
assert c.networking.hostName == "rakku";
assert builtins.all (driver: builtins.elem driver c.boot.initrd.availableKernelModules) [
  "ahci"
  "xhci_pci"
  "usb_storage"
  "sd_mod"
];
assert c.system.stateVersion == "24.11";
assert c.fileSystems."/".fsType == "tmpfs";
assert c.fileSystems."/nix".device == "/dev/disk/by-partlabel/disk-main-root";
assert c.fileSystems."/tundra/permafrost".neededForBoot;
assert c.fileSystems."/boot".device == "/dev/disk/by-partlabel/disk-main-ESP";
assert builtins.length c.swapDevices == 1;
assert (builtins.head c.swapDevices).device == "/dev/disk/by-partlabel/disk-main-swap";
assert !(c ? disko);
assert builtins.all (path: builtins.elem path directories) [
  "/var/lib/hass"
  "/var/lib/tailscale"
  "/var/cache/private"
  "/home/simonwjackson"
  "/var/lib/tsnet-proxy-habitat"
];
# Home Assistant is the official image, pinned by digest, on the persisted
# config directory, with the Zigbee radio at the path its config entry stores.
assert builtins.match "ghcr\\.io/home-assistant/home-assistant:.*@sha256:[0-9a-f]{64}" ha.image != null;
assert ha.serviceName == "home-assistant";
assert builtins.elem "/var/lib/hass:/config" ha.volumes;
assert
  ha.devices == [
    "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if01-port0:/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if01-port0"
  ];
assert builtins.elem "/var/lib/containers" c.systemd.services.home-assistant.unitConfig.RequiresMountsFor;
assert c.systemd.timers.hass-config-commit.wantedBy == [ "timers.target" ];
# The Z-Wave server has no authentication. The LAN and tailnet interfaces are
# trusted, so it must listen on loopback only.
assert builtins.match ".* --host 127\\.0\\.0\\.1 .*" zwaveExec != null;
assert c.users.users.hass.uid == 286 && c.users.groups.hass.gid == 286;
assert c.users.users.simonwjackson.uid == 1000 && c.users.users.simon.uid == 1001;
assert
  c.services.zwave-js.serialPort
  == "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if00-port0";
assert c.services.zwave-js.settings.storage.cacheDir == "/var/cache/zwave-js";
assert c.services.zwave-js.secretsConfigFile == c.sops.secrets.zwave-js-secrets.path;
assert
  c.sops.secrets.withings-api-key.sopsFile == ../secrets/hosts/rakku.yaml
  && c.sops.secrets.withings-api-key.mode == "0400";
assert c.sops.age.sshKeyPaths == [ "/tundra/permafrost/etc/ssh/ssh_host_ed25519_key" ];
assert !c.services.home-assistant.enable;
assert !c.networking.networkmanager.enable && c.networking.useDHCP;
assert
  c.networking.firewall.enable && builtins.elem "enp1s0" c.networking.firewall.trustedInterfaces;
assert c.services.tinyproxy.enable && c.systemd.services.airconnect.enable;
assert c.systemd.services.tailscale-join.enable;
{
  status = "pass";
  toplevel = c.system.build.toplevel.outPath;
  inherit haExec zwaveExec directories;
  haImage = ha.image;
  sshKeys = map (key: key.path) c.services.openssh.hostKeys;
  versions = {
    zwaveServer = c.services.zwave-js.package.version;
  };
}
