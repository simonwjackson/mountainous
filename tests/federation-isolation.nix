# Standalone VM check. No host imports, private state, or deploy entry point.
{
  pkgs ? import <nixpkgs> {},
  testScript ? builtins.readFile ./federation-isolation-vm.py,
}: let
  lib = pkgs.lib;
  systemUnits = ["korrid" "korrid-identity" "sunshine" "korri-bundle-selector" "inputplumber" "korri-inputd" "korri-input-seat-receiver" "korri-compositor"];
  userUnits = ["korrid" "sunshine" "x11-headless"];
  implementation = pkgs.writeText "federation_isolation.py" (builtins.readFile ../scripts/federation_isolation.py);
  driver = pkgs.writeText "isolation-vm-driver.py" (builtins.readFile ./federation-isolation-driver.py);
  authenticatedSystemctl = pkgs.writeScriptBin "systemctl" ''
    #!${pkgs.python3}/bin/python3
    import os
    import sys
    if "--user" in sys.argv:
        assert os.getresuid() == (1000, 1000, 1000)
        assert os.getresgid() == (100, 100, 100)
        assert os.getgroups() == []
        assert os.environ["XDG_RUNTIME_DIR"] == "/run/user/1000"
        assert os.environ["DBUS_SESSION_BUS_ADDRESS"] == "unix:path=/run/user/1000/bus"
        assert os.environ["SYSTEMCTL_FORCE_BUS"] == "1"
        assert os.environ["HOME"] == "/home/operator"
        assert os.environ["USER"] == os.environ["LOGNAME"] == "operator"
        assert not any(arg.startswith("--machine") for arg in sys.argv)
    else:
        assert os.geteuid() == 0
    os.execv("${pkgs.systemd}/bin/systemctl", ["systemctl", *sys.argv[1:]])
  '';
  fixture = pkgs.writeShellScriptBin "isolation-fixture" ''
    export PATH=${authenticatedSystemctl}/bin:$PATH
    export ISOLATION_MODULE=${implementation}
    exec ${pkgs.python3}/bin/python3 ${driver} "$@"
  '';
  requestSupervisor = pkgs.writeShellScript "isolation-fixture-request-supervisor" ''
    # This fixture-only sudo command has no caller-selected unit or arguments.
    test "$#" = 0 && test "$SUDO_UID" = 1000 || exit 64
    exec ${pkgs.systemd}/bin/systemd-run --unit=fixture-supervisor \
      --service-type=exec --property=User=root --property=KillMode=control-group \
      ${fixture}/bin/isolation-fixture independent-supervisor
  '';
  caller = pkgs.writeShellScript "isolation-fixture-caller" ''
    set -eu
    echo $$ > /run/user/1000/fixture-caller-pid
    /run/wrappers/bin/sudo -n ${requestSupervisor}
    touch /run/user/1000/fixture-caller-requested
    exec ${pkgs.coreutils}/bin/sleep infinity
  '';
  keys = pkgs.runCommand "isolation-fixture-ssh-key" {nativeBuildInputs = [pkgs.openssh];} ''
    mkdir "$out"
    ssh-keygen -q -t ed25519 -N "" -f "$out/key"
  '';
  service = name: {
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      Restart = "always";
    };
  };
in
  assert lib.versions.major pkgs.systemd.version == "259";
    pkgs.testers.runNixOSTest {
      name = "federation-maintenance-isolation";
      nodes.machine = {config, ...}: {
        virtualisation.memorySize = 2048;
        virtualisation.cores = 2;
        virtualisation.useBootLoader = true;
        boot.loader.grub.enable = true;
        system.stateVersion = "26.05";
        environment.systemPackages = [fixture pkgs.python3 pkgs.openssh];
        environment.etc."isolation-vm-fixture".text = "isolated fixture only\n";
        environment.etc."fixture-generation".text = lib.mkDefault "old\n";
        services.openssh.enable = true;
        # Pinned util-linux pam_lastlog2 has an unresolved pam_syslog symbol in this
        # minimal VM. Keep real PAM/authentication, omit only login-history recording.
        security.pam.services.login.updateWtmp = lib.mkForce false;
        security.pam.services.sshd.updateWtmp = lib.mkForce false;
        users.users.root.openssh.authorizedKeys.keyFiles = ["${keys}/key.pub"];
        environment.etc."fixture-key" = {
          source = "${keys}/key";
          mode = "0600";
        };
        security.sudo.extraRules = [
          {
            users = ["operator"];
            commands = [
              {
                command = "${requestSupervisor}";
                options = ["NOPASSWD"];
              }
            ];
          }
        ];
        users.users.operator = {
          isNormalUser = true;
          uid = 1000;
          linger = true;
        };
        systemd.tmpfiles.rules = [
          "d /home/operator/.config 0755 operator users -"
          "d /home/operator/.config/systemd 0755 operator users -"
          "d /home/operator/.config/systemd/user 0755 operator users -"
          "L /home/operator/.config/systemd/user/sunshine.service - - - - /dev/null"
        ];
        systemd.services =
          lib.genAttrs systemUnits service
          // {
            management = {
              wantedBy = ["multi-user.target"];
              serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
            };
            fixture-blocker.serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.coreutils}/bin/sleep 15";
            };
          };
        systemd.sockets.korrid-control = {
          wantedBy = ["sockets.target"];
          socketConfig = {
            ListenStream = "/run/fixture-korrid.sock";
            Service = "korrid.service";
          };
        };
        systemd.sockets.korri-certificate-control = {
          wantedBy = ["sockets.target"];
          socketConfig = {
            ListenStream = "/run/fixture-certificate.sock";
            Service = "sunshine.service";
          };
        };
        systemd.user.services =
          lib.genAttrs userUnits (name: {
            wantedBy = ["default.target"];
            serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          })
          // {
            fixture-caller.serviceConfig = {
              Type = "exec";
              ExecStart = caller;
            };
            fixture-blocker.serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.coreutils}/bin/sleep 15";
            };
          };
        systemd.user.sockets.korrid-control = {
          wantedBy = ["sockets.target"];
          socketConfig = {
            ListenStream = "%t/fixture-korrid.sock";
            Service = "korrid.service";
          };
        };
        specialisation.candidate.configuration.environment.etc."fixture-generation".text = lib.mkForce "candidate\n";
        specialisation.recovery.configuration.environment.etc."fixture-generation".text = lib.mkForce "recovery\n";
        system.userActivationScripts.isolationHang = ''
          if test -e /run/fixture-hang-user-activation; then
            echo $$ > /run/user/1000/fixture-user-activation-pid
            ${pkgs.coreutils}/bin/sleep infinity &
            echo $! > /run/user/1000/fixture-user-activation-child
            touch /run/user/1000/fixture-user-activation-waiting
            wait
          fi
        '';
        # Failure occurs in the real generation activation, after setup-etc.
        system.activationScripts.isolationFailure = {
          deps = ["etc"];
          text = ''
            if test -e /run/fixture-hang-activation; then
              touch /run/fixture-activation-waiting
              while ! test -e /run/fixture-release-activation; do
                ${pkgs.coreutils}/bin/sleep 0.1
              done
              rm /run/fixture-activation-waiting
            fi
            if test -e /run/fixture-fail-activation; then
              echo "isolation fixture: deliberate activation failure" >&2
              exit 23
            fi
          '';
        };
      };
      inherit testScript;
    }
