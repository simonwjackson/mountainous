{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  inherit (pkgs) writeScriptBin;

  cfg = config.mountainous.bluetooth-tether;

  bluetooth-network-script = writeScriptBin "bluetooth-network" ''
    #!/bin/sh

    DEVICE_ADDRESS="$1"

    if [ -z "$DEVICE_ADDRESS" ]; then
      echo "Usage: $0 <device_address>"
      exit 1
    fi

    # Start bt-network
    ${pkgs.bluez-tools}/bin/bt-network -c "$DEVICE_ADDRESS" nap
  '';

  bluetooth-dhcp-script = writeScriptBin "bluetooth-dhcp" ''
    #!/bin/sh

    DEVICE_NAME="$1"

    if [ -z "$DEVICE_NAME" ]; then
      echo "Usage: $0 <device_name>"
      exit 1
    fi

    # Wait for the network interface to appear
    for i in $(${pkgs.coreutils}/bin/seq 1 30); do
      IFACE=$(${pkgs.iproute2}/bin/ip link | ${pkgs.gnugrep}/bin/grep -o 'enp[0-9]\+s[0-9]\+u[0-9]\+' | ${pkgs.coreutils}/bin/tail -n 1)
      if [ -n "$IFACE" ]; then
        echo "Network interface $IFACE detected for $DEVICE_NAME"
        break
      fi
      if [ $i -eq 30 ]; then
        echo "Timed out waiting for network interface for $DEVICE_NAME"
        exit 1
      fi
      sleep 1
    done

    # Request DHCP lease and keep the process running
    exec ${pkgs.dhcpcd}/bin/dhcpcd -B -d "$IFACE"
  '';

  mkBluetoothServices = device: let
    escapedName = builtins.replaceStrings [" "] ["-"] device.name;
  in {
    "bluetooth-network-${escapedName}" = {
      description = "Bluetooth Network Service for ${device.name}";
      after = ["network.target" "bluetooth.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "15s";
        ExecStart = "${bluetooth-network-script}/bin/bluetooth-network '${device.macAddress}' '${device.name}'";
      };
    };

    "bluetooth-dhcp-${escapedName}" = {
      description = "Bluetooth DHCP Service for ${device.name}";
      after = ["bluetooth-network-${escapedName}.service"];
      requires = ["bluetooth-network-${escapedName}.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "forking";
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${bluetooth-dhcp-script}/bin/bluetooth-dhcp '${device.name}'";
        PIDFile = "/run/dhcpcd-${escapedName}.pid";
      };

      bindsTo = ["bluetooth-network-${escapedName}.service"];
      partOf = ["bluetooth-network-${escapedName}.service"];
    };
  };
in {
  options.mountainous.bluetooth-tether = {
    enable = mkEnableOption "Bluetooth tethering service";

    devices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the device (used for service names)";
            example = "My Phone";
          };
          macAddress = mkOption {
            type = types.str;
            description = "Bluetooth MAC address of the device";
            example = "XX:XX:XX:XX:XX:XX";
          };
        };
      });
      description = "List of Bluetooth devices to connect for tethering";
      default = [];
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      bluetooth-network-script
      bluetooth-dhcp-script
    ];

    systemd.services = lib.mkMerge (map mkBluetoothServices cfg.devices);

    # Ensure dhcpcd is installed
    networking.dhcpcd.enable = true;
  };
}
