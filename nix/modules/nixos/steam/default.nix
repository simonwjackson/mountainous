{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.steam;

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
  options.mountainous.steam = {
    enable = lib.mkEnableOption "Enable steam";
  };

  config = lib.mkIf cfg.enable {
    # mountainous.services.gamescope-reaper.enable = true;

    hardware = {
      steam-hardware.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    # Note: Not enabling jovian.steam directly due to power key conflicts
    # Instead, we'll use Jovian's packages via the flake

    # Optional: Enable Jovian's Decky loader for Steam Deck plugins
    # jovian.decky.enable = true;

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
                # Use stable gamescope from nixpkgs (not git versions)
                # Removed problematic gamescope_git which causes Vulkan errors on AMD
                gamescope
                # Optional: Use Jovian packages if available
                # (pkgs.jovian-chaotic.gamescope or gamescope)
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
          # Keep proton-ge-custom for latest Proton improvements
          inputs.elevate.packages.x86_64-linux.proton-ge-custom
        ];
      };
    };
  };
}
