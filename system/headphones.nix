{ config, pkgs, ... }:
let
  bluetoothMonitorScript = pkgs.writeScript "bluetooth_monitor.sh" ''
    #!/bin/sh

    # Set the Bluetooth device address
    DEVICE_ADDRESS="CC:98:8B:93:2A:1F"

    # Set the path to the FIFO file
    FIFO_PATH="/tmp/bluetooth_status.fifo"

    # Create the FIFO if it doesn't exist, and set its permissions
    if [ ! -e "$FIFO_PATH" ]; then
      mkfifo "$FIFO_PATH"
      chmod 666 "$FIFO_PATH"
      chown root:root "$FIFO_PATH"
    fi


    # Monitor the Bluetooth device connection status
    ${pkgs.dbus}/bin/dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1',path='/org/bluez/hci0/dev_''${DEVICE_ADDRESS//:/_}'" | \
    while read -r line; do
      if echo "$line" | grep -q "boolean true"; then
        echo "1" > "$FIFO_PATH"
      elif echo "$line" | grep -q "boolean false"; then
        echo "0" > "$FIFO_PATH"
      fi
    done
  '';
in
{
  # Enable Bluetooth support
  hardware.bluetooth.enable = true;

  # Define the systemd service

  systemd.services.bluetooth-monitor = {
    enable = true;
    description = "Bluetooth Device Connection Monitor";
    after = [ "bluetooth.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.bluez ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${bluetoothMonitorScript}";
      User = "root";
    };
  };
}
