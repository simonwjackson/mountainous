{
  pkgs,
  lib,
}: let
  inherit (lib) escapeShellArg;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  journalctl = "${pkgs.systemd}/bin/journalctl";
  grep = "${pkgs.gnugrep}/bin/grep";
in rec {
  # Create the onConnect script for Sunshine
  # Switches to virtual monitor when a client connects
  # Parameters:
  #   - primary: primary monitor name (e.g., "eDP-1")
  #   - virtual: virtual monitor name (e.g., "HDMI-A-2")
  #   - resolution: target resolution (e.g., "3840x2160@60")
  #   - scaling: display scaling factor (default: 1)
  makeOnConnect = {
    primary,
    virtual,
    resolution,
    scaling ? 1,
  }:
    pkgs.writeShellScript "sunshine-on-connect" ''
      set -e

      # Get Hyprland instance signature
      HYPRLAND_INSTANCE_SIGNATURE=$(${hyprctl} instances | head -1 | awk '{print $NF}')
      export HYPRLAND_INSTANCE_SIGNATURE

      # Configure virtual monitor with specified resolution and scaling
      ${hyprctl} --instance 0 keyword monitor ${virtual},${resolution},auto,${toString scaling}

      # Ensure display is powered on
      ${hyprctl} --instance 0 dispatch dpms on
    '';

  # Create the onDisconnect script
  # Restores primary monitor when client disconnects
  # Parameters:
  #   - primary: primary monitor name (e.g., "eDP-1")
  makeOnDisconnect = {primary}:
    pkgs.writeShellScript "sunshine-on-disconnect" ''
      set -e

      # Get Hyprland instance signature
      HYPRLAND_INSTANCE_SIGNATURE=$(${hyprctl} instances | head -1 | awk '{print $NF}')
      export HYPRLAND_INSTANCE_SIGNATURE

      # Reload configuration to restore primary monitor settings
      ${hyprctl} --instance 0 reload
    '';

  # Helper to wait for disconnect event from Sunshine service
  # Monitors journal and executes callback script when disconnect is detected
  # Parameters:
  #   - callbackScript: script to execute when disconnect detected
  makeWaitForDisconnect = {callbackScript}:
    pkgs.writeShellScript "sunshine-wait-for-disconnect" ''
      set -e

      # Wait for client disconnect event in journal, then execute callback
      ${journalctl} --user -u sunshine.service -f |
        ${grep} -q "CLIENT DISCONNECTED" && exec "${callbackScript}"
    '';

  # Simplified version that directly runs the disconnect script
  # Used when you want to directly specify the onDisconnect behavior
  makeWaitForDisconnectWithScript = {onDisconnectScript}:
    pkgs.writeShellScript "sunshine-disconnect-handler" ''
      set -e

      ${journalctl} --user -u sunshine.service -f |
        ${grep} -q "CLIENT DISCONNECTED" && ${onDisconnectScript}
    '';

  # Helper to get Hyprland instance signature
  # This can be used in scripts to ensure proper communication with Hyprland
  getHyprlandSignature = pkgs.writeShellScript "get-hyprland-signature" ''
    ${hyprctl} instances | head -1 | awk '{print $NF}'
  '';

  # Create a complete Sunshine application configuration
  # Combines all the above helpers into a ready-to-use application config
  # Parameters:
  #   - name: application name (displayed in Sunshine UI)
  #   - primary: primary monitor name
  #   - virtual: virtual monitor name
  #   - resolution: target resolution
  #   - scaling: display scaling (default: 1)
  makeSunshineApp = {
    name,
    primary,
    virtual,
    resolution,
    scaling ? 1,
  }: let
    onConnectScript = makeOnConnect {inherit primary virtual resolution scaling;};
    onDisconnectScript = makeOnDisconnect {inherit primary;};
    waitScript = makeWaitForDisconnectWithScript {inherit onDisconnectScript;};
  in {
    inherit name;
    prep-cmd = [
      {
        do = onConnectScript;
        undo = "";
      }
    ];
    cmd = waitScript;
    exclude-global-prep-cmd = "false";
    auto-detach = "false";
    wait-all = "false";
  };
}
