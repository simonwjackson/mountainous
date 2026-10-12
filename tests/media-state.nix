# Filesystem metadata tests need Linux ACL/xattr support, not Nix's syscall filter.
{
  pkgs,
  nzbget,
  transmission,
}:
let
  fixtures = pkgs.runCommand "media-state-test-programs" { } ''
    mkdir -p "$out/scripts" "$out/modules"
    cp ${../scripts/media-state} "$out/scripts/media-state"
    cp ${../scripts/media-inventory-target} "$out/scripts/media-inventory-target"
    cp ${../scripts/test-media-state.py} "$out/scripts/test-media-state.py"
    cp ${../scripts/test-media-native-transfer.py} "$out/scripts/test-media-native-transfer.py"
    cp ${../scripts/test-media-state-ready.py} "$out/scripts/test-media-state-ready.py"
    cp ${../scripts/test-media-nzbget-hold.py} "$out/scripts/test-media-nzbget-hold.py"
    cp ${../scripts/test-media-transmission-hold.py} "$out/scripts/test-media-transmission-hold.py"
    cp ${../modules/media-state-ready.py} "$out/modules/media-state-ready.py"
    cp ${../modules/media-nzbget-launch.py} "$out/modules/media-nzbget-launch.py"
    cp ${../modules/media-nzbfast-settings.py} "$out/modules/media-nzbfast-settings.py"
    cp ${../scripts/media-nzbfast-provision.py} "$out/scripts/media-nzbfast-provision.py"
    cp ${../scripts/test-media-nzbfast-provision.py} "$out/scripts/test-media-nzbfast-provision.py"
    cp ${../scripts/test-media-nzbfast-settings.py} "$out/scripts/test-media-nzbfast-settings.py"
    cp ${../scripts/media-vpn-leak-audit.py} "$out/scripts/media-vpn-leak-audit.py"
    cp ${../scripts/test-media-vpn-leak-audit.py} "$out/scripts/test-media-vpn-leak-audit.py"
    cp ${../modules/media-library-cleanup.py} "$out/modules/media-library-cleanup.py"
    cp ${../scripts/test-media-library-cleanup.py} "$out/scripts/test-media-library-cleanup.py"
  '';
in
pkgs.testers.runNixOSTest {
  name = "media-state-preservation";
  nodes.machine = {
    virtualisation.memorySize = 1024;
    users.users.fixture = {
      isNormalUser = true;
      uid = 1000;
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.gnutar
      pkgs.rsync
    ];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    with subtest("metadata preservation runs as a normal file owner"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-state.py")
    with subtest("native tar and rsync preserve the numeric ownership and ACL contract"):
        machine.succeed("python3 ${fixtures}/scripts/test-media-native-transfer.py")
    with subtest("existing-state and ARR processing holds"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-state-ready.py")
    with subtest("NZBFAST provisioning and service-owned settings are private and idempotent"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-nzbfast-provision.py")
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-nzbfast-settings.py")
    with subtest("VPN audit selects declared services without skipping expected inactive units"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-vpn-leak-audit.py")
    with subtest("pinned NZBGet starts with native processing holds"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-nzbget-hold.py ${nzbget}/bin/nzbget")
    with subtest("empty title cleanup preserves library roots and files"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-library-cleanup.py")
    with subtest("pinned Transmission holds saved running torrents and ignores watch files"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-transmission-hold.py ${transmission}/bin/transmission-daemon")
  '';
}
