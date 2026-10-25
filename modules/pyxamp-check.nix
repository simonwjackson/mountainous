# Check the evaluated fleet contract, then the packaged face's real IPC path.
{
  self,
  inputs,
  config,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      package = inputs.pyxamp.packages.${system}.default;
      hosts = config.nixos.hosts;
      desktop = name: builtins.elem "desktop" hosts.${name}.layers;
      present = c: c.systemd.user.services ? pyxamp-daemon || c.systemd.user.services ? pyxamp;
      sessionUnit =
        unit:
        builtins.elem "graphical-session.target" unit.partOf
        && builtins.elem "graphical-session.target" unit.after
        && builtins.elem "graphical-session.target" unit.wantedBy
        && unit.environment.DBUS_SESSION_BUS_ADDRESS == "unix:path=%t/bus"
        && unit.serviceConfig.Restart == "on-failure"
        && unit.serviceConfig.Slice == "session.slice";
      valid =
        name:
        let
          c = self.nixosConfigurations.${name}.config;
          p = c.mountainous.features.pyxamp.package;
          daemon = c.systemd.user.services.pyxamp-daemon;
          face = c.systemd.user.services.pyxamp;
        in
        if desktop name then
          c.mountainous.features.pyxamp.enable
          && builtins.elem p c.environment.systemPackages
          &&
            toString c.hjem.users.simon.files.".config/quickshell/pyxamp".source
            == "${p}/etc/xdg/quickshell/pyxamp"
          && sessionUnit daemon
          && sessionUnit face
          && daemon.serviceConfig.ExecStart == "${p}/bin/pyxamp-daemon"
          && builtins.elem "pipewire.service" daemon.after
          && face.serviceConfig.ExecStart == "${p}/bin/pyxamp"
          && face.environment.QT_QPA_PLATFORM == "wayland"
          && builtins.elem "pyxamp-daemon.service" face.after
          && builtins.elem "pyxamp-daemon.service" face.wants
        else
          !(present c);
      disabled =
        (self.nixosConfigurations.myoko.extendModules {
          modules = [ { mountainous.features.pyxamp.enable = false; } ];
        }).config;
      myoko = self.nixosConfigurations.myoko.config;
      bindings = builtins.readFile ./hyprland/hyprland.lua;
      has = text: lib.hasInfix text bindings;
    in
    {
      checks.pyxamp-desktop =
        assert builtins.all valid (builtins.attrNames hosts);
        assert desktop "myoko" && desktop "hiyori" && !(desktop "ibuki");
        assert !(present disabled);
        assert !(disabled.hjem.users.simon.files ? ".config/quickshell/pyxamp");
        assert
          !(builtins.elem disabled.mountainous.features.pyxamp.package disabled.environment.systemPackages);
        assert builtins.elem "graphical-session.target" myoko.systemd.user.targets.hyprland-session.bindsTo;
        assert inputs.pyxamp.rev == "c08f2f0b1048f3a1f47f23a8dad942c484f44b9a";
        assert package.quickshell.version == "0.3.2";
        assert has ''hl.bind(mod .. " + Z", hl.dsp.exec_cmd("pyxamp ipc call pyxamp toggle"))'';
        assert has ''hl.dsp.exec_cmd("playerctl --player=pyxamp play-pause")'';
        assert has ''hl.dsp.exec_cmd("playerctl --player=pyxamp next")'';
        assert has ''hl.dsp.exec_cmd("playerctl --player=pyxamp previous")'';
        pkgs.runCommand "pyxamp-desktop"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.dbus
              pkgs.labwc
              pkgs.jq
              pkgs.lua
            ];
            PYXAMP = package;
            QS = "${package.quickshell}/bin/qs";
            DESKTOP_QS = "${pkgs.quickshell}/bin/qs";
            FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
          }
          ''
            luac -p ${./hyprland/hyprland.lua}
            dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- bash ${../tests/pyxamp-desktop.sh}
            touch $out
          '';
    };
}
