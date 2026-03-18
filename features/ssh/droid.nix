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

    # Bind mosh-server to the Tailscale interface so the UDP data
    # channel is not reachable from other networks.
    TAILSCALE_IP=$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null)
    if [[ -n "$TAILSCALE_IP" ]]; then
      exec ${pkgs.mosh}/bin/mosh-server -i "$TAILSCALE_IP" "$@"
    else
      echo "mosh-server: could not determine Tailscale IP, refusing to start" >&2
      exit 1
    fi
  '';

  # Wrap the mosh client so dnshack's LD_PRELOAD is preserved through
  # Nix binary wrappers. Without this, mosh resolves hostnames with
  # plain getaddrinfo which bypasses the dnshack bridge on Android.
  moshClientWrapper = pkgs.writeShellScriptBin "mosh" ''
    export LD_PRELOAD="''${LD_PRELOAD:-}"
    export DNSHACK_RESOLVER_CMD="''${DNSHACK_RESOLVER_CMD:-}"
    exec ${pkgs.mosh}/bin/mosh "$@"
  '';
in {
  config = lib.mkIf cfg.enable {
    environment.packages =
      [pkgs.openssh]
      ++ lib.optionals (cfg.authorizedKeysUrl != null) [pkgs.curl]
      ++ lib.optionals cfg.mosh.enable [
        (lib.hiPrio moshServerWrapper)
        (lib.hiPrio moshClientWrapper)
        pkgs.mosh
      ];

    mountainous.features.session-services.sshd = let
      # Wrapper that kills any orphaned sshd on our port before starting,
      # so we recover from manually-started instances that service-ensure
      # doesn't track.
      sshdWrapper = pkgs.writeShellScript "sshd-wrapper" ''
        if [[ -f "${pidFile}" ]]; then
          pid=$(<"${pidFile}")
          if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            ${pkgs.coreutils}/bin/sleep 1
          fi
          ${pkgs.coreutils}/bin/rm -f "${pidFile}"
        fi
        exec ${pkgs.openssh}/bin/sshd -D -f ${configFile}
      '';
    in {
      enable = true;
      command = "${sshdWrapper}";
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
      ClientAliveInterval 30
      ClientAliveCountMax 3
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
