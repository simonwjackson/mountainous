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
          && wiring c
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
      withSecrets =
        on:
        (self.nixosConfigurations.myoko.extendModules {
          modules = [
            {
              mountainous.features.pyxamp.sources.pyxis.enable = on;
              mountainous.features.pyxamp.sources.jellyfin.enable = on;
            }
          ];
        }).config;
      # Both secret keys present, and both absent, whatever Myoko's file holds.
      configured = withSecrets true;
      unprovisioned = withSecrets false;
      keyIn =
        name: key:
        let
          file = ../secrets/desktop + "/${name}.yaml";
        in
        builtins.pathExists file && lib.hasInfix "\n${key}:" ("\n" + builtins.readFile file);
      pyxampSecrets = c: lib.filter (lib.hasPrefix "pyxamp/") (builtins.attrNames c.sops.secrets);
      ownSecret =
        c: name: key:
        let
          s = c.sops.secrets.${name};
        in
        s.key == key
        && s.owner == "simon"
        && s.mode == "0400"
        && s.path == "/run/secrets/${name}"
        && toString s.sopsFile == toString (../secrets/desktop + "/${c.networking.hostName}.yaml");
      # A source with a secret is wired exactly when its key is in the host's file.
      wiring =
        c:
        let
          s = c.mountainous.features.pyxamp.sources;
          host = c.networking.hostName;
          file = c.systemd.user.services.pyxamp-daemon.environment.PYXAMP_SOURCES;
        in
        s.pyxis.enable == keyIn host "pyxamp-pyxis-token"
        && s.jellyfin.enable == keyIn host "pyxamp-jellyfin-api-key"
        && s.ossicle.enable
        && (c.sops.secrets ? "pyxamp/pyxis-token") == s.pyxis.enable
        && (c.sops.secrets ? "pyxamp/jellyfin-api-key") == s.jellyfin.enable
        && toString c.hjem.users.simon.files.".config/pyxamp/sources.toml".source == file;
      bindings = builtins.readFile ./hyprland/hyprland.lua;
      has = text: lib.hasInfix text bindings;
    in
    {
      checks.pyxamp-desktop =
        assert builtins.all valid (builtins.attrNames hosts);
        assert desktop "myoko" && desktop "hiyori" && !(desktop "ibuki");
        assert !(present disabled);
        assert !(disabled.hjem.users.simon.files ? ".config/quickshell/pyxamp");
        assert !(disabled.hjem.users.simon.files ? ".config/pyxamp/sources.toml");
        assert pyxampSecrets disabled == [ ];
        # Without keys no Pyxamp secret is declared, so activation cannot fail.
        assert pyxampSecrets unprovisioned == [ ];
        assert
          pyxampSecrets configured == [
            "pyxamp/jellyfin-api-key"
            "pyxamp/pyxis-token"
          ];
        assert ownSecret configured "pyxamp/pyxis-token" "pyxamp-pyxis-token";
        assert ownSecret configured "pyxamp/jellyfin-api-key" "pyxamp-jellyfin-api-key";
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
              pkgs.yq-go
            ];
            SOURCES_UNCONFIGURED = unprovisioned.systemd.user.services.pyxamp-daemon.environment.PYXAMP_SOURCES;
            SOURCES_CONFIGURED = configured.systemd.user.services.pyxamp-daemon.environment.PYXAMP_SOURCES;
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
