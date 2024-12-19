{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming.steam;

  steamWrapper = pkgs.writeShellScriptBin "steam" ''
    # Path to localconfig.vdf
    CONFIG_FILE="$HOME/.local/share/Steam/userdata/80924811/config/localconfig.vdf"

    # If the file exists, modify the SignIntoFriends setting
    if [ -f "$CONFIG_FILE" ]; then
      sed -i 's/"SignIntoFriends".*"1"/"SignIntoFriends"\t\t"0"/g' "$CONFIG_FILE"
    fi

    # Launch Steam with all customizations
    exec "$STEAM_ORIGINAL" "$@"
  '';
in {
  options.mountainous = {
    gaming.steam = {
      enable = lib.mkEnableOption "Enable steam";
    };
  };

  config = lib.mkIf cfg.enable {
    mountainous.services.gamescope-reaper.enable = true;

    hardware = {
      steam-hardware.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        extest.enable = true;
        package =
          (pkgs.steam.override {
            extraPkgs = pkgs:
              with pkgs; [
                mangohud
                gamescope-wsi_git
                gamescope_git
              ];
          })
          .overrideAttrs (old: {
            buildCommand = ''
              # Run the original build command
              ${old.buildCommand}

              # Store the path to the original steam binary
              mv $out/bin/steam $out/bin/steam-original

              # Create our wrapper that knows where to find the original
              cat > $out/bin/steam << EOF
              #!${pkgs.bash}/bin/bash
              export STEAM_ORIGINAL="$out/bin/steam-original"
              exec ${steamWrapper}/bin/steam "\$@"
              EOF

              chmod +x $out/bin/steam
            '';
          });
        extraCompatPackages = [
          inputs.elevate.packages.${system}.proton-ge-custom
        ];
      };
    };
  };
}
