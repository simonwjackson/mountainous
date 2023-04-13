{ pkgs, ... }: {
  services.flatpak.enable = true;
  services.dbus.packages = [
    (pkgs.writeTextFile {
      name = "dbus-monitor-policy";
      text = ''
        <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
          "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
          <policy user="simonwjackson">
            <allow send_destination="org.freedesktop.DBus" send_interface="org.freedesktop.DBus.Monitoring" />
            <allow send_type="method_call" send_interface="org.freedesktop.DBus.Monitoring"/>
            <allow send_type="signal" send_interface="org.freedesktop.DBus.Properties" send_member="PropertiesChanged" send_path="/org/bluez"/>
          </policy>
        </busconfig>
      '';
      destination = "/etc/dbus-1/system.d/dbus-monitor-policy.conf";
    })
  ];
}
