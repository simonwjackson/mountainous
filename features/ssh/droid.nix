{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.features.ssh.server;
  userName = config.user.userName;
  home = config.user.home;
  sshDir = "${home}/.ssh";
  hostKey = "${sshDir}/ssh_host_ed25519_key";
  authorizedKeys = "${sshDir}/authorized_keys";
  pidFile = "${sshDir}/sshd.pid";
  configFile = "${sshDir}/sshd_config";
  port = toString cfg.port;
  sshSessionPath = lib.concatStringsSep ":" [
    "/etc/profiles/per-user/${userName}/bin"
    "${home}/.nix-profile/bin"
    "/nix/var/nix/profiles/per-user/${userName}/profile/bin"
    "/nix/profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
  allowedAddresses = lib.unique (cfg.allowedCidrs ++ ["127.0.0.1/32" "::1/128"]);
  deniedAddressPattern = "*,!" + lib.concatStringsSep ",!" allowedAddresses;

  moshServerWrapper = pkgs.writeShellScriptBin "mosh-server" ''
    export LANG="''${LANG:-C.UTF-8}"
    export LC_CTYPE="''${LC_CTYPE:-$LANG}"
    exec ${pkgs.mosh}/bin/mosh-server "$@"
  '';
in {
  config = lib.mkIf cfg.enable {
    environment.packages =
      [pkgs.openssh]
      ++ lib.optionals (cfg.authorizedKeysUrl != null) [pkgs.curl]
      ++ lib.optionals cfg.mosh.enable [
        (lib.hiPrio moshServerWrapper)
        pkgs.mosh
      ];

    mountainous.sessionServices.sshd = {
      enable = true;
      command = "${pkgs.openssh}/bin/sshd -D -f ${configFile}";
    };

    home-manager.config.programs.ssh = {
      enable = true;
      matchBlocks.localhost = {
        hostname = "localhost";
        port = cfg.port;
        user = userName;
        identityFile = ["${sshDir}/id_rsa"];
        identitiesOnly = true;
      };
    };

    build.activationAfter.sshd = ''
      mkdir -p "${sshDir}"
      chmod 700 "${sshDir}"

      if [[ ! -f "${hostKey}" ]]; then
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "${hostKey}" -N ""
      fi

      ${lib.optionalString (cfg.authorizedKeysUrl != null) ''
        if [[ ! -s "${authorizedKeys}" ]]; then
          ${pkgs.curl}/bin/curl -fsSL '${cfg.authorizedKeysUrl}' > "${authorizedKeys}"
          chmod 600 "${authorizedKeys}"
        fi
      ''}

      cat > "${configFile}" <<'EOF'
      Port ${port}
      HostKey ${hostKey}
      AuthorizedKeysFile ${authorizedKeys}
      StrictModes no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthenticationMethods publickey
      SetEnv PATH=${sshSessionPath}
      SetEnv LANG=C.UTF-8
      PidFile ${pidFile}
      ${lib.optionalString (cfg.allowedCidrs != []) ''
        Match Address ${deniedAddressPattern}
          PubkeyAuthentication no
      ''}
      EOF
      chmod 600 "${configFile}"
    '';
  };
}
