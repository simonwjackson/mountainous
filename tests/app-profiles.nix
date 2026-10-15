{
  hosts,
  deploy,
  unzen,
  lib,
}:
assert builtins.all (
  name:
  let
    c = hosts.${name}.config;
  in
  c.mountainous.appProfiles.pi.enable
  && c.mountainous.appProfiles.pi.profilePath == "/nix/var/nix/profiles/apps/pi"
  && c.mountainous.appDeployment.enable
  && c.mountainous.appDeployment.deployPublicKey == unzen.mountainous.appDeployment.deployPublicKey
  && c.mountainous.appDeployment.signingPublicKey == unzen.mountainous.appDeployment.signingPublicKey
  && c.mountainous.appDeployment.builderPublicKey == unzen.mountainous.appDeployment.builderPublicKey
  && builtins.elem "restrict ${c.mountainous.appDeployment.deployPublicKey}" c.users.users.app-deploy.openssh.authorizedKeys.keys
  && builtins.elem c.mountainous.appDeployment.signingPublicKey c.nix.settings.trusted-public-keys
  && (
    name != "fuji"
    || builtins.elem "restrict,command=\"${c.nix.package}/bin/nix-daemon --stdio\" ${c.mountainous.appDeployment.builderPublicKey}" c.users.users.simon.openssh.authorizedKeys.keys
  )
  && c.users.users.app-deploy.isSystemUser
  && !(builtins.elem "wheel" c.users.users.app-deploy.extraGroups)
  && !(builtins.elem "app-deploy" c.nix.settings.trusted-users)
  && lib.hasPrefix "/run/" c.sops.secrets.pi-cliproxyapi-api-key.path
  && c.sops.secrets.pi-cliproxyapi-api-key.owner == "simon"
  && c.sops.secrets.pi-cliproxyapi-api-key.mode == "0400"
  && lib.hasPrefix "/run/" c.sops.secrets.pi-decide-api-key.path
  && c.sops.secrets.pi-decide-api-key.owner == "simon"
  && c.sops.secrets.pi-decide-api-key.mode == "0400"
  && !(builtins.any (m: m.where == "/var/lib/pi/simon/agent/settings.json") c.systemd.mounts)
  && deploy.nodes.${name}.profiles.pi.profilePath == c.mountainous.appProfiles.pi.profilePath
  && deploy.nodes.${name}.sshUser == "app-deploy"
  && deploy.nodes.${name}.user == "app-deploy"
  && deploy.nodes.${name}.magicRollback
  && deploy.nodes.${name}.autoRollback
  && builtins.elem "d /home/simon/.pi/agent 0700 simon users -" c.systemd.tmpfiles.rules
  && builtins.elem "L /home/simon/.pi/agent/settings.json - - - - /home/simon/.local/share/fleet-sync/pi/settings.json" c.systemd.tmpfiles.rules
) (builtins.attrNames hosts);
assert unzen.systemd.timers.app-update-pi.timerConfig.OnCalendar == "*-*-* 00,06,12,18:00:00 UTC";
assert unzen.systemd.services.app-update-pi.serviceConfig.UMask == "0077";
assert
  unzen.systemd.services.app-update-pi.environment.LOCAL_KEY == "/var/lib/app-updater/signing-key";
assert
  unzen.systemd.services.app-update-pi.environment.NIX_SSHOPTS == "-F /dev/null -o BatchMode=yes";
{
  status = "pass";
}
