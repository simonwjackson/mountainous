# Isolated combined test. The systemd managers and all maintenance primitives are real.
{
  pkgs,
  package,
  selectorPackage,
  sunshinePackage,
  smoke ? false,
  faultsOnly ? false,
  proofsOnly ? false,
  probesOnly ? false,
}: let
  lib = pkgs.lib;
  # The actual six-check producer with VM topology (no physical by-id disks).
  commitments =
    (import ../hosts/zao/commitments.nix {
      inherit lib pkgs;
      config = {};
    }).config.mountainous.hosts.zao.runtimeVerifier;
  oldKorrid = builtins.storePath "/nix/store/i9jv1fgl4zdxqr1garq9c2g8jm3igcz2-korrid-0.0.0";
  generator = package.verifier.overrideAttrs (old: {
    pname = "federation-cutover-synthetic-fixture-generator";
    src = pkgs.runCommand "federation-cutover-fixture-generator-source" {} ''
      mkdir -p "$out"
      cp -R --no-preserve=mode,ownership ${old.src}/. "$out/"
      cp ${./federation-cutover-fixture.rs} "$out/src/bin/federation-cutover-fixture.rs"
    '';
    buildPhase =
      old.buildPhase
      + ''
        cargo build --release --locked --bin federation-cutover-fixture
      '';
    postInstall =
      old.postInstall
      + ''
        install -Dm755 target/release/federation-cutover-fixture "$out/bin/federation-cutover-fixture"
      '';
  });
  identities =
    pkgs.runCommand "federation-cutover-synthetic-identities" {
      nativeBuildInputs = [pkgs.openssl];
    } ''
      mkdir -p "$out"
      ${pkgs.python3.withPackages (p: [p.cryptography])}/bin/python3 ${./federation-cutover-driver.py} certificates "$out/certs"
      for name in client-one client-two server; do
        for time in 1788998400 2082758400; do
          openssl verify -attime "$time" -CAfile "$out/certs/$name.crt" "$out/certs/$name.crt"
        done
      done
      ${generator}/bin/federation-cutover-fixture "$out" "$out/certs/client-one.crt"
    '';
  components = pkgs.runCommand "federation-cutover-fixture-components" {} ''
    mkdir -p "$out/bin" "$out/share/inputplumber/profiles"
    for name in inputplumber korri-inputd korri-input-seat-receiver; do
      ln -s ${pkgs.coreutils}/bin/sleep "$out/bin/$name"
    done
    ln -s ${package.verifier}/bin/korrid "$out/bin/korrid"
    echo fixture > "$out/share/inputplumber/profiles/korri-60-xbox_one_gamepad.yaml"
  '';
  bundle = label:
    pkgs.runCommand "korri-bundle-fixture-${label}" {} ''
      mkdir -p "$out/bin" "$out/share"
      for name in inputplumber korri-inputd korri-input-seat-receiver; do
        ln -s ${components}/bin/$name "$out/bin/$name"
      done
      ln -s ${
        if label == "candidate"
        then package.verifier
        else oldKorrid
      }/bin/korrid "$out/bin/korrid"
      ln -s ${components}/share/inputplumber "$out/share/inputplumber"
      ln -s ${components}/share/inputplumber/profiles/korri-60-xbox_one_gamepad.yaml "$out/share/korri-input-profile"
    '';
  oldBundle = bundle "old";
  candidateBundle = bundle "candidate";
  recoveryBundle = bundle "recovery";
  metadata = pkgs.writeText "cutover-fixture-metadata.json" (builtins.toJSON {
    inherit identities oldBundle candidateBundle recoveryBundle;
    runner = "${package}/bin/federation-cutover";
    library = "${package}/lib";
    sunshine = "${sunshinePackage}/bin/sunshine";
    sleep = "${pkgs.coreutils}/bin/sleep";
    ip = "${pkgs.iproute2}/bin/ip";
  });
  fixture = pkgs.writeShellScriptBin "cutover-fixture" ''
    exec ${pkgs.python3}/bin/python3 -B ${./federation-cutover-driver.py} ${metadata} "$@"
  '';
  request = pkgs.writeShellScript "cutover-fixture-request" ''
    test "$#" = 0 && test "$SUDO_UID" = 1000 || exit 64
    exec ${fixture}/bin/cutover-fixture launch
  '';
  caller = pkgs.writeShellScript "cutover-fixture-caller" ''
    /run/wrappers/bin/sudo -n ${request}
    touch /run/user/1000/cutover-caller-requested
    exec ${pkgs.coreutils}/bin/sleep infinity
  '';
  systemUnits = ["korri-inputd" "inputplumber" "korri-input-seat-receiver"];
  base = {config, ...}: {
    networking.hostName = "zao";
    networking.firewall.trustedInterfaces = ["relay-host"];
    system.name = config.virtualisation.test.nodeName;
    system.stateVersion = "26.05";
    virtualisation.memorySize = 4096;
    virtualisation.diskSize = 16384;
    virtualisation.fileSystems."/".autoResize = true;
    boot.growPartition = true;
    virtualisation.cores = 2;
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    virtualisation.qemu.options = ["-rtc" "base=2026-09-06T00:00:00,clock=vm"];
    services.timesyncd.enable = false;
    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = true;
    environment.systemPackages = [package fixture commitments pkgs.python3 pkgs.nftables pkgs.util-linux pkgs.openssh pkgs.xfsprogs pkgs.mergerfs pkgs.cups pkgs.curl];
    boot.kernelModules = ["loop" "xfs" "fuse"];
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };
    services.strfry = {
      enable = true;
      settings.events.rejectEventsOlderThanSeconds = 2147483647;
      settings.relay.bind = "192.0.2.2";
    };
    services.jellyfin.enable = true;
    services.printing.enable = true;
    services.avahi.enable = true;
    services.tailscale = {
      enable = true;
      extraDaemonFlags = ["--no-logs-no-support"];
    };
    services.headscale = {
      enable = true;
      settings = {
        server_url = "http://127.0.0.1:8080";
        dns = {
          magic_dns = false;
          override_local_dns = false;
          base_domain = "fixture.invalid";
          nameservers.global = [];
        };
        # The fixture crashes these guests on purpose. Headscale's own keys are
        # created on first start and are not fsynced, so a crashed guest can come
        # back with an unparseable key and fail `tailnet-access` for a reason that
        # has nothing to do with the supervisor. Read fixed disposable keys from
        # the store instead: no runtime write, nothing to lose in a crash. A
        # global sync is deliberately not used, because it would also mask the
        # supervisor's own durability, which these tests exist to prove.
        noise.private_key_path = toString (pkgs.writeText "fixture-noise.key" "privkey:0000000000000000000000000000000000000000000000000000000000000031\n");
        derp = {
          urls = [];
          server = {
            enabled = true;
            region_id = 999;
            stun_listen_addr = "127.0.0.1:3478";
            private_key_path = toString (pkgs.writeText "fixture-derp.key" "privkey:0000000000000000000000000000000000000000000000000000000000000032\n");
          };
        };
      };
    };
    systemd.targets.towada-array.wantedBy = ["multi-user.target"];
    systemd.targets.towada-merged.wantedBy = ["multi-user.target"];
    systemd.timers = lib.genAttrs ["towada-snapraid-sync" "towada-snapraid-scrub" "towada-cache-mover" "media-tiering-peer-mount"] (_: {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1y";
        OnUnitActiveSec = "1y";
      };
    });
    environment.etc."federation-cutover-fixture".text = "disposable synthetic VM only\n";
    environment.etc."korrid/host.toml".text = ''
      label = "zao"
    '';
    services.openssh.enable = true;
    security.pam.services.login.updateWtmp = lib.mkForce false;
    security.pam.services.sshd.updateWtmp = lib.mkForce false;
    users.groups.korrid.gid = 976;
    users.groups.korri-control.gid = 977;
    users.groups.korri-sunshine-input-seat.gid = 980;
    users.users.korrid = {
      isSystemUser = true;
      uid = 976;
      group = "korrid";
    };
    users.users.korri-inputd = {
      isSystemUser = true;
      uid = 977;
      group = "korri-control";
    };
    users.users.simonwjackson = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      linger = true;
    };
    security.sudo.extraRules = [
      {
        users = ["simonwjackson"];
        commands = [
          {
            command = "${request}";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
    systemd.tmpfiles.rules = [
      "d /home/simonwjackson/.config 0755 simonwjackson users -"
      "d /home/simonwjackson/.config/systemd 0755 simonwjackson users -"
      "d /home/simonwjackson/.config/systemd/user 0755 simonwjackson users -"
      "L /home/simonwjackson/.config/systemd/user/sunshine.service - - - - /dev/null"
      "d /run/korri-certificate-control 0751 root korrid -"
      "d /run/korrid-control 0750 root korri-control -"
    ];
    systemd.services =
      lib.genAttrs systemUnits (name: {
        serviceConfig = {
          # coreutils is a multi-call ELF. Keep the selected path but supply its
          # real sleep argv[0] through systemd's documented @ command prefix.
          ExecStart = "@${components}/bin/${name} sleep infinity";
          User =
            if name == "korri-inputd"
            then "korri-inputd"
            else "root";
          Group =
            if name == "korri-inputd"
            then "korri-control"
            else "root";
        };
      })
      // {
        strfry = {
          requires = ["cutover-relay-network.service"];
          after = ["cutover-relay-network.service"];
          serviceConfig.NetworkNamespacePath = "/run/netns/cutover-relay";
        };
        # Only the network fabric is adapted: the shipped relay transport allows
        # plaintext WS solely on loopback. This real UID976 TCP route crosses the
        # veth, so the unchanged nft UID policy still blocks publication pre-cut.
        cutover-relay-route = {
          wantedBy = ["multi-user.target"];
          requires = ["strfry.service"];
          after = ["strfry.service"];
          serviceConfig = {
            User = "korrid";
            Group = "korrid";
            ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:7777,bind=127.0.0.1,reuseaddr,fork TCP:192.0.2.2:7777";
          };
        };
        cutover-relay-network = {
          wantedBy = ["multi-user.target"];
          path = [pkgs.iproute2];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${fixture}/bin/cutover-fixture relay-network";
          };
        };
        # A configurable real status transport, not a replacement for systemctl or
        # proof of the full host daemon. The destructive primitives are unmodified.
        korrid = {
          requires = ["korrid-control.socket"];
          after = ["korrid-control.socket"];
          environment = {
            KORRID_GAMEPLAY_UID = "1000";
            KORRID_GAMEPLAY_GID = "100";
            KORRID_PRIVATE_STATE_ROOT = "/var/lib/korrid";
            KORRID_SUNSHINE_PRIVATE_STATE_ROOT = "/home/simonwjackson/.config/sunshine";
            KORRI_BUNDLE_ACTIVE = "/nix/var/nix/gcroots/korri-bundle/active";
            KORRID_SUNSHINE_CERTIFICATE_CONTROL_SOCKET = "/run/korri-certificate-control/control.sock";
            KORRID_SUNSHINE_CERTIFICATE_CONTROL_GID = "976";
            KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_UID = "0";
            KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_GID = "0";
          };
          serviceConfig = {
            ExecStart = "${fixture}/bin/cutover-fixture status-server";
            User = "korrid";
            Group = "korrid";
            Sockets = ["korrid-control.socket"];
          };
        };
        korrid-identity.serviceConfig = {
          Type = "oneshot";
          ExecStart = "${package.verifier}/bin/korrid identity import --file ${identities}/old.json";
          User = "korrid";
          Group = "korrid";
        };
        korrid-identity.environment.KORRID_PRIVATE_STATE_ROOT = "/var/lib/korrid";
        korri-bundle-selector.serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${selectorPackage}/bin/korri-bundle-select initialize ${oldBundle}";
        };
        korri-input-source-guard.serviceConfig = {ExecStart = "${pkgs.coreutils}/bin/sleep infinity";};
        korri-compositor.serviceConfig = {
          ExecStart = "${pkgs.xorg-server}/bin/Xvfb :0 -screen 0 1280x720x24 -ac";
          User = "simonwjackson";
          Group = "users";
        };
        sunshine = {
          requires = ["korri-certificate-control.socket" "korri-compositor.service" "korri-input-seat-receiver.service" "korri-bundle-selector.service" "korri-input-source-guard.service"];
          after = ["korri-certificate-control.socket" "korri-compositor.service" "korri-input-seat-receiver.service"];
          environment = {
            DISPLAY = ":0";
            HOME = "/home/simonwjackson";
            KORRI_CERTIFICATE_CONTROL_UID = "976";
            KORRI_CERTIFICATE_CONTROL_GID = "976";
            KORRI_CERTIFICATE_CONTROL_OWNER_GID = "976";
            KORRI_CERTIFICATE_CONTROL_MODE = "0660";
            KORRI_CERTIFICATE_CONTROL_PATH = "/run/korri-certificate-control/control.sock";
          };
          serviceConfig = {
            ExecStart = "${sunshinePackage}/bin/sunshine /home/simonwjackson/.config/sunshine/sunshine.conf log_path=/dev/null";
            ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
            Sockets = ["korri-certificate-control.socket"];
            User = "simonwjackson";
            Group = "korri-sunshine-input-seat";
            WorkingDirectory = "/home/simonwjackson";
          };
        };
        towada-mergerfs-mount = {
          path = [pkgs.util-linux pkgs.mergerfs];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${fixture}/bin/cutover-fixture storage-mounts";
          };
          wantedBy = ["multi-user.target"];
          unitConfig.ConditionPathExists = "/var/lib/cutover-storage/00.xfs";
        };
        media-tiering-tv-mount = {
          wantedBy = ["multi-user.target"];
          unitConfig.ConditionPathExists = "/var/lib/cutover-storage/00.xfs";
          requires = ["towada-mergerfs-mount.service"];
          after = ["towada-mergerfs-mount.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.mergerfs}/bin/mergerfs -o minfreespace=16M /srv/lakes/towada/media/tv /srv/range/media/tv";
          };
        };
        media-tiering-movies-mount = {
          wantedBy = ["multi-user.target"];
          unitConfig.ConditionPathExists = "/var/lib/cutover-storage/00.xfs";
          requires = ["towada-mergerfs-mount.service"];
          after = ["towada-mergerfs-mount.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.mergerfs}/bin/mergerfs -o minfreespace=16M /srv/lakes/towada/media/movies /srv/range/media/movies";
          };
        };
        jellyfin-seed-bootstrap.wantedBy = ["multi-user.target"];
        jellyfin-seed-bootstrap.serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.curl}/bin/curl --fail --retry 60 --retry-delay 1 --retry-all-errors http://127.0.0.1:8096/health";
        };
        # Real local TCP proxy replaces only the fixture's external tsnet topology.
        tsnet-proxy-jellyfin.wantedBy = ["multi-user.target"];
        tsnet-proxy-jellyfin.serviceConfig.ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:8097,reuseaddr,fork TCP:127.0.0.1:8096";
        ensure-office-printer.wantedBy = ["multi-user.target"];
        ensure-office-printer.after = ["cups.service"];
        ensure-office-printer.path = [pkgs.cups];
        ensure-office-printer.serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${fixture}/bin/cutover-fixture printer";
        };
      }
      // lib.genAttrs ["towada-snapraid-sync" "towada-snapraid-scrub" "towada-cache-mover" "media-tiering-peer-mount"] (_: {
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/sleep 0";
        };
      });
    systemd.sockets.korrid-control.socketConfig = {
      ListenStream = "/run/korrid-control/control.sock";
      Service = "korrid.service";
      SocketUser = "root";
      SocketGroup = "korri-control";
      SocketMode = "0660";
    };
    systemd.sockets.korri-certificate-control.socketConfig = {
      ListenSequentialPacket = "/run/korri-certificate-control/control.sock";
      SocketUser = "root";
      SocketGroup = "korrid";
      SocketMode = "0660";
      FileDescriptorName = "korri-certificate-control";
      NonBlocking = true;
      RemoveOnStop = true;
      DirectoryMode = "0751";
      Service = "sunshine.service";
    };
    systemd.user.services =
      lib.genAttrs ["korrid" "sunshine" "x11-headless"] (_: {
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      })
      // {cutover-caller.serviceConfig.ExecStart = caller;};
    systemd.user.sockets.korrid-control.socketConfig = {
      ListenStream = "%t/fixture-legacy-control.sock";
      Service = "korrid.service";
    };
    specialisation = let
      candidate = {
        systemd.services.korrid.wantedBy = ["multi-user.target"];
        systemd.services.korrid.requires = ["korrid-identity.service" "sunshine.service" "inputplumber.service" "korri-inputd.service"];
        systemd.services.korrid.after = ["korrid-identity.service" "sunshine.service"];
        systemd.services.korrid.serviceConfig.ExecStart = lib.mkForce "${candidateBundle}/bin/korrid";
        systemd.services.korrid.environment = lib.mkForce {
          KORRID_RUNTIME_UID = "1000";
          KORRID_RUNTIME_GID = "100";
          KORRID_MODE = "host";
          KORRID_ADDRESS = "0.0.0.0:39217";
          KORRID_HOST_CONFIG = "/etc/korrid/host.toml";
          KORRID_STORAGE_ROOT = "/var/lib/korri";
          KORRID_CONTROL_PEER_UID = "977";
          KORRID_CONTROL_PEER_GID = "977";
          KORRID_SYSTEMCTL = "${pkgs.systemd}/bin/systemctl";
          KORRID_SYSTEMD_RUN = "${pkgs.systemd}/bin/systemd-run";
          KORRID_RELAYS = ''["ws://127.0.0.1:7777"]'';
          KORRID_ADVERTISED_ENDPOINTS = ''["http://127.0.0.1:39217"]'';
          KORRID_PRIVATE_STATE_ROOT = "/var/lib/korrid";
          KORRID_SUNSHINE_PRIVATE_STATE_ROOT = "/home/simonwjackson/.config/sunshine";
          KORRI_BUNDLE_ACTIVE = "/nix/var/nix/gcroots/korri-bundle/active";
          KORRID_SUNSHINE_CERTIFICATE_CONTROL_SOCKET = "/run/korri-certificate-control/control.sock";
          KORRID_SUNSHINE_CERTIFICATE_CONTROL_GID = "976";
          KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_UID = "0";
          KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_GID = "0";
        };
        systemd.services.korrid-identity.serviceConfig.ExecStart = lib.mkForce "${package.verifier}/bin/korrid identity import --file ${identities}/new.json";
        systemd.services.korri-bundle-selector.serviceConfig.ExecStart = lib.mkForce "${selectorPackage}/bin/korri-bundle-select initialize ${candidateBundle}";
      };
    in {
      candidate.configuration = candidate;
      secondconfig.configuration = {
        imports = [candidate];
        systemd.services.sunshine.serviceConfig.ExecStart = lib.mkForce "${sunshinePackage}/bin/sunshine /home/simonwjackson/.config/sunshine/sunshine.conf /home/simonwjackson/.config/sunshine/other.conf";
      };
      namespace.configuration = {
        imports = [candidate];
        systemd.services.sunshine.serviceConfig.PrivateNetwork = true;
      };
      recovery.configuration = {
        systemd.services.korrid.wantedBy = ["multi-user.target"];
        systemd.services.korrid.requires = ["korrid-identity.service" "sunshine.service" "inputplumber.service" "korri-inputd.service"];
        systemd.services.korrid.after = ["korrid-identity.service" "sunshine.service"];
        systemd.services.korrid.serviceConfig.ExecStart = lib.mkForce "${recoveryBundle}/bin/korrid";
        systemd.services.korrid.environment = {
          KORRID_MODE = "host";
          KORRID_ADDRESS = "0.0.0.0:39217";
          KORRID_HOST_CONFIG = "/etc/korrid/host.toml";
          KORRID_STORAGE_ROOT = "/var/lib/korri";
          KORRID_CONTROL_PEER_UID = "977";
          KORRID_CONTROL_PEER_GID = "977";
          KORRID_SYSTEMCTL = "${pkgs.systemd}/bin/systemctl";
          KORRID_SYSTEMD_RUN = "${pkgs.systemd}/bin/systemd-run";
        };
        systemd.services.korrid-identity.serviceConfig.ExecStart = lib.mkForce "${oldKorrid}/bin/korrid identity import --file ${identities}/new.json";
        systemd.services.korri-bundle-selector.serviceConfig.ExecStart = lib.mkForce "${selectorPackage}/bin/korri-bundle-select initialize ${recoveryBundle}";
      };
    };
    system.activationScripts.cutoverFixtureFailure = {
      deps = ["etc"];
      text = ''
        if test -e /run/cutover-fixture-hold; then
          touch /run/cutover-fixture-activation-waiting
          while test -e /run/cutover-fixture-hold; do ${pkgs.coreutils}/bin/sleep 0.1; done
        fi
        if test -e /run/cutover-fixture-fail; then exit 23; fi
      '';
    };
  };
in
  assert lib.versions.major pkgs.systemd.version == "259";
    pkgs.testers.runNixOSTest {
      name = "federation-cutover-combined";
      nodes =
        if probesOnly
        then lib.genAttrs ["revokefailed" "revokereceipt" "restartrace"] (_: base)
        else if proofsOnly
        then lib.genAttrs ["journalfacts" "grantfacts" "commitmentfailure" "statechange" "legacymembership"] (_: base)
        else if faultsOnly
        then lib.genAttrs ["handshake" "permits" "beforetable" "aftertable" "finalrelease"] (_: base)
        else
          {success = base;}
          // lib.optionalAttrs (!smoke) {
            failed = base;
            interrupted = base;
            securityfailed = {...}: {
              imports = [base];
              specialisation.candidate.configuration.environment.etc."korrid/host.toml".text = lib.mkForce "label = [invalid\n";
            };
            releasefailed = {...}: {
              imports = [base];
              boot.loader.systemd-boot.extraInstallCommands = ''
                if test -e /run/cutover-fixture-release-fail; then
                  printf '# fixture concurrent guard writer\n' >> /etc/systemd/system.control/korrid.service.d/90-korri-maintenance-isolation.conf
                fi
              '';
            };
          };
      testScript =
        if probesOnly
        then ''
          for node, phase in ((revokefailed, "probe-revoke"), (revokereceipt, "probe-receipt")):
              with subtest("authenticated automatic provisioning failure retains facts: " + phase):
                  node.start()
                  node.wait_for_unit("multi-user.target")
                  node.wait_for_unit("user@1000.service")
                  node.wait_for_unit("headscale.service")
                  node.wait_for_unit("strfry.service")
                  node.succeed("systemctl --version | grep 'systemd 259'")
                  node.succeed("cutover-fixture setup", timeout=180)
                  node.succeed("systemd-run --unit=cutover-manifest-fault cutover-fixture fault-manifest " + phase)
                  node.wait_for_file("/run/cutover-fault-ready")
                  node.succeed("cutover-fixture launch")
                  node.wait_until_succeeds("test -e /run/cutover-fault-fired || test -e /var/lib/korri-maintenance-isolation/failure-held.json || systemctl is-failed cutover-manifest-fault.service", timeout=450)
                  print(node.succeed("journalctl -u korri-cutover-supervisor.service -u cutover-manifest-fault.service --no-pager"))
                  node.succeed("test -e /run/cutover-fault-fired")
                  node.wait_for_file("/run/korri-cutover-recovery.sock", timeout=90)
                  node.succeed("cutover-fixture assert-probe-held", timeout=180)
                  node.crash()
                  node.start()
                  node.wait_for_unit("multi-user.target")
                  node.wait_for_unit("user@1000.service")
                  node.wait_until_succeeds("cutover-fixture assert-fault-boot", timeout=180)
                  node.shutdown()

          with subtest("actual Sunshine stop signals never precede its running main loop"):
              restartrace.start()
              restartrace.wait_for_unit("multi-user.target")
              restartrace.wait_for_unit("user@1000.service")
              restartrace.wait_for_unit("headscale.service")
              restartrace.wait_for_unit("strfry.service")
              restartrace.succeed("systemctl --version | grep 'systemd 259'")
              restartrace.succeed("cutover-fixture setup", timeout=180)
              print(restartrace.succeed("cutover-fixture sunshine-restart-race", timeout=900))
              print(restartrace.succeed("journalctl -u sunshine.service -o short-monotonic --no-pager"))
              restartrace.shutdown()
        ''
        else if proofsOnly
        then ''
          for node, phase in ((journalfacts, "journal"), (grantfacts, "grant"), (commitmentfailure, "commitment"), (statechange, "state"), (legacymembership, "legacy")):
              with subtest("acceptance-time facts remain unchanged and prohibit downgrade: " + phase):
                  node.start()
                  node.wait_for_unit("multi-user.target")
                  node.wait_for_unit("user@1000.service")
                  node.wait_for_unit("headscale.service")
                  node.wait_for_unit("strfry.service")
                  node.succeed("cutover-fixture setup", timeout=180)
                  node.succeed("systemd-run --unit=cutover-manifest-fault cutover-fixture fault-manifest " + phase)
                  node.wait_for_file("/run/cutover-fault-ready")
                  node.succeed("cutover-fixture launch")
                  node.wait_for_file("/run/cutover-fault-fired", timeout=450)
                  node.wait_for_file("/var/lib/korri-maintenance-isolation/failure-held.json", timeout=240)
                  node.wait_for_file("/run/korri-cutover-recovery.sock", timeout=60)
                  print(node.succeed("journalctl -u korri-cutover-supervisor.service --no-pager"))
                  node.succeed("cutover-fixture assert-facts-held", timeout=300)
                  node.shutdown()
        ''
        else if faultsOnly
        then ''
          failures = []
          for node, phase in ((handshake, "handshake"), (permits, "permits"), (beforetable, "before-table"), (aftertable, "after-table"), (finalrelease, "final-release")):
              with subtest("real manifest.next open denial: " + phase):
                  node.start()
                  node.wait_for_unit("multi-user.target")
                  node.wait_for_unit("user@1000.service")
                  node.wait_for_unit("headscale.service")
                  node.wait_for_unit("strfry.service")
                  node.succeed("cutover-fixture setup", timeout=180)
                  node.succeed("systemd-run --unit=cutover-manifest-fault cutover-fixture fault-manifest " + phase)
                  node.wait_for_file("/run/cutover-fault-ready")
                  node.succeed("cutover-fixture launch")
                  node.wait_until_succeeds("test -e /run/cutover-fault-fired || systemctl is-failed korri-cutover-supervisor.service cutover-manifest-fault.service", timeout=450)
                  print(node.succeed("journalctl -u korri-cutover-supervisor.service -u cutover-manifest-fault.service --no-pager"))
                  node.succeed("test -e /run/cutover-fault-fired")
                  try:
                      node.wait_until_succeeds("cutover-fixture assert-emergency-stopped", timeout=60)
                  except Exception:
                      failures.append(phase)
                  print(node.succeed("journalctl -u korri-cutover-supervisor.service --no-pager"))
                  if phase not in failures:
                      node.crash()
                      node.start()
                      node.wait_for_unit("multi-user.target")
                      node.wait_for_unit("user@1000.service")
                      node.wait_until_succeeds("cutover-fixture assert-fault-boot", timeout=120)
                  node.shutdown()
          assert not failures, failures
        ''
        else if smoke
        then ''
          start_all()
          success.wait_for_unit("multi-user.target")
          success.wait_for_unit("user@1000.service")
          success.wait_for_unit("headscale.service")
          success.wait_for_unit("strfry.service")
          success.succeed("cutover-fixture setup", timeout=180)
          success.succeed("cutover-fixture preflight-review")
          success.succeed("cutover-fixture launch")
          success.wait_until_succeeds("test -e /var/lib/korri-maintenance-isolation/released.json || test -e /var/lib/korri-maintenance-isolation/failure-held.json", timeout=400)
          print(success.succeed("journalctl -u korri-cutover-supervisor.service -u korrid.service -u sunshine.service --no-pager"))
          print(success.succeed("cutover-fixture phase"))
          if success.execute("test -e /var/lib/korri-maintenance-isolation/failure-held.json")[0] == 0:
              # Diagnostic assertions never turn the required positive lifecycle green.
              print(success.succeed("cutover-fixture assert-incomplete-probe-held", timeout=180))
              success.crash()
              success.start()
              success.wait_for_unit("multi-user.target")
              success.wait_for_unit("user@1000.service")
              print(success.succeed("cutover-fixture assert-incomplete-probe-boot", timeout=180))
          success.succeed("test -e /var/lib/korri-maintenance-isolation/released.json")
          success.succeed("cutover-fixture assert-accepted")
          success.succeed("cutover-fixture relay-cache-refuses", timeout=180)
        ''
        else builtins.readFile ./federation-cutover-vm.py;
    }
