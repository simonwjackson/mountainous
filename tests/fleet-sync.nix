{ hosts, lib }:
builtins.all (
  name:
  let
    c = hosts.${name};
    s = c.services.syncthing;
  in
  if name == "fuji" then
    !s.enable
  else
    s.enable
    && s.overrideDevices
    && s.overrideFolders
    && !s.openDefaultPorts
    && lib.hasPrefix "unix://" s.guiAddress
    && !s.settings.options.globalAnnounceEnabled
    && !s.settings.options.localAnnounceEnabled
    && !s.settings.options.relaysEnabled
    && !s.settings.options.natEnabled
    && !(builtins.elem 8384 c.networking.firewall.allowedTCPPorts)
    && !(builtins.elem 22000 c.networking.firewall.allowedTCPPorts)
    && builtins.elem 22000 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts
    &&
      s.settings.folders.pi.ignorePatterns == [
        "!/settings.json"
        "*"
      ]
    && builtins.all (d: !d.introducer && !d.autoAcceptFolders && d.addresses != [ "dynamic" ]) (
      lib.attrValues s.settings.devices
    )
    && builtins.all (peer: s.settings.devices ? ${peer}) s.settings.folders.pi.devices
) (lib.attrNames hosts)
