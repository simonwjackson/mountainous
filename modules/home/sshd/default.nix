{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf hm;
  cfg = config.services.sshd;
in {
  options.services.sshd = {
    enable = mkEnableOption "SSHD Service for Nix-on-Droid";

    port = mkOption {
      type = types.port;
      default = 8022;
      description = "Port on which sshd should listen";
    };

    authorizedKeys = mkOption {
      type = types.lines;
      default = "";
      description = "Authorized public keys for SSH access";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines to be added to sshd_config";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.openssh];

    home.activation.setupSshd = hm.dag.entryAfter ["writeBoundary"] ''
      # Generate SSH host key if it doesn't exist
      if [ ! -f "${config.home.homeDirectory}/.ssh/ssh_host_rsa_key" ]; then
        $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f ${config.home.homeDirectory}/.ssh/ssh_host_rsa_key -N ""
      fi

      # Ensure .ssh directory exists
      $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.ssh"

      # Set up authorized_keys file
      AUTH_KEYS_FILE="${config.home.homeDirectory}/.ssh/authorized_keys"
      $DRY_RUN_CMD touch "$AUTH_KEYS_FILE"

      # Read existing keys into an array
      IFS=$'\n' read -d "" -r -a existing_keys < "$AUTH_KEYS_FILE"

      # Add new keys, avoiding duplicates
      echo "${cfg.authorizedKeys}" | while read -r new_key; do
        if [[ -n "$new_key" ]]; then
          is_duplicate=0
          for existing_key in "''${existing_keys[@]}"; do
            if [[ "$existing_key" == "$new_key" ]]; then
              is_duplicate=1
              break
            fi
          done
          if [[ $is_duplicate -eq 0 ]]; then
            $DRY_RUN_CMD echo "$new_key" >> "$AUTH_KEYS_FILE"
          fi
        fi
      done

      $DRY_RUN_CMD chmod 600 "$AUTH_KEYS_FILE"
    '';

    home.file.".local/bin/start-sshd.sh" = {
      executable = true;
      text = ''
        #!/bin/sh
        if [ ! -f /tmp/sshd.pid ]; then
          ${pkgs.openssh}/bin/sshd -f ${config.home.homeDirectory}/.ssh/sshd_config -E ${config.home.homeDirectory}/.ssh/sshd.log
        fi
      '';
    };

    home.file.".ssh/sshd_config" = {
      text = ''
        HostKey ${config.home.homeDirectory}/.ssh/ssh_host_rsa_key
        Port ${toString cfg.port}
        PermitRootLogin no
        PubkeyAuthentication yes
        PasswordAuthentication no
        ChallengeResponseAuthentication no
        UsePAM no
        PrintMotd no
        AcceptEnv LANG LC_*
        AuthorizedKeysFile ${config.home.homeDirectory}/.ssh/authorized_keys

        ${cfg.extraConfig}
      '';
    };

    programs.bash.initExtra = ''
      ${config.home.homeDirectory}/.local/bin/start-sshd.sh
      # empty line
    '';
  };
}
