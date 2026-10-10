# Filesystem metadata tests need Linux ACL/xattr support, not Nix's syscall filter.
{ pkgs, nzbget }:
let
  fixtures = pkgs.runCommand "media-state-test-programs" { } ''
    mkdir -p "$out/scripts" "$out/modules"
    cp ${../scripts/media-state} "$out/scripts/media-state"
    cp ${../scripts/media-inventory-target} "$out/scripts/media-inventory-target"
    cp ${../scripts/test-media-state.py} "$out/scripts/test-media-state.py"
    cp ${../scripts/test-media-state-ready.py} "$out/scripts/test-media-state-ready.py"
    cp ${../scripts/test-media-nzbget-hold.py} "$out/scripts/test-media-nzbget-hold.py"
    cp ${../modules/media-state-ready.py} "$out/modules/media-state-ready.py"
    cp ${../modules/media-nzbget-launch.py} "$out/modules/media-nzbget-launch.py"
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
    environment.systemPackages = [ pkgs.python3 ];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    with subtest("metadata preservation runs as a normal file owner"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-state.py")
    with subtest("existing-state and ARR processing holds"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-state-ready.py")
    with subtest("pinned NZBGet starts with native processing holds"):
        machine.succeed("runuser -u fixture -- python3 ${fixtures}/scripts/test-media-nzbget-hold.py ${nzbget}/bin/nzbget")
  '';
}
