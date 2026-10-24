# Deployment gates for the real evaluated host, not a duplicate module fixture.
c:
let
  persistence = c.environment.persistence."/tundra/permafrost";
  directories = map (
    entry: if builtins.isString entry then entry else entry.directory
  ) persistence.directories;
  haExec = c.systemd.services.home-assistant.serviceConfig.ExecStart;
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
assert builtins.match ".*4xdbwlvdmkd278fzy69bawfj1df487m5-homeassistant-2025.12.3.*" haExec != null;
assert
  builtins.match ".*rirnmd7dk9ikj4fw51n5fwjvsbb7q2s0-zwave-js-server-3.4.0.*" zwaveExec != null;
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
assert c.services.home-assistant.configDir == "/var/lib/hass";
assert
  c.services.home-assistant.config.homeassistant.external_url
  == "https://habitat.hummingbird-lake.ts.net";
assert c.services.home-assistant.config.homeassistant.internal_url == "http://localhost:8123";
assert !c.networking.networkmanager.enable && c.networking.useDHCP;
assert
  c.networking.firewall.enable && builtins.elem "enp1s0" c.networking.firewall.trustedInterfaces;
assert c.services.tinyproxy.enable && c.systemd.services.airconnect.enable;
assert c.systemd.services.tailscale-join.enable;
{
  status = "pass";
  toplevel = c.system.build.toplevel.outPath;
  inherit haExec zwaveExec directories;
  haConfiguration = c.services.home-assistant.config;
  sshKeys = map (key: key.path) c.services.openssh.hostKeys;
  versions = {
    homeAssistant = c.services.home-assistant.package.version;
    zwaveServer = c.services.zwave-js.package.version;
  };
}
