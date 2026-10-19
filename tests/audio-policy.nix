# Prove the default-device policy of modules/audio.nix in a VM:
#
#   - the highest priority.session wins, whatever was chosen before
#   - a manual choice wins until a device node comes or goes
#   - a restart of WirePlumber restores no stored choice
#
# Null sinks stand in for real devices. They have no card, so they test the
# ranking and the forget script, not the per-device rules.
{ pkgs, audio }:
pkgs.testers.runNixOSTest {
  name = "audio-policy";
  nodes.machine = {
    imports = [ audio ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      linger = true;
    };
  };
  testScript = ''
    def user(command):
        return machine.succeed(
            "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 " + command
        )

    def sink(name, priority):
        user(
            "pw-cli create-node adapter '{ factory.name=support.null-audio-sink "
            f"node.name={name} media.class=Audio/Sink object.linger=true "
            f"audio.position=[FL FR] priority.session={priority} }}'"
        )

    def default_sink():
        return user("wpctl inspect @DEFAULT_AUDIO_SINK@")

    def wait_default(name):
        machine.wait_until_succeeds(
            "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 "
            f"wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -F 'node.name = \"{name}\"'",
            timeout=30,
        )

    def node_id(name):
        return user(
            f"pw-dump | ${pkgs.jq}/bin/jq -r '.[] | select(.info.props.\"node.name\"==\"{name}\") | .id'"
        ).strip()

    machine.wait_for_unit("user@1000.service")
    machine.wait_until_succeeds(
        "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 wpctl status", timeout=60
    )
    machine.wait_until_succeeds(
        "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active wireplumber",
        timeout=60,
    )

    with subtest("the highest priority wins"):
        sink("speakers", 1000)
        sink("headphones", 3000)
        wait_default("headphones")

    with subtest("a manual choice wins until a device comes"):
        user("wpctl set-default " + node_id("speakers"))
        wait_default("speakers")
        sink("monitor-jack", 500)
        wait_default("headphones")

    with subtest("a manual choice wins until a device goes"):
        user("wpctl set-default " + node_id("speakers"))
        wait_default("speakers")
        user("pw-cli destroy " + node_id("monitor-jack"))
        wait_default("headphones")

    with subtest("a restart restores no stored choice"):
        user("wpctl set-default " + node_id("speakers"))
        wait_default("speakers")
        user("systemctl --user restart wireplumber")
        wait_default("headphones")
        machine.fail("test -e /home/alice/.local/state/wireplumber/default-nodes")
  '';
}
