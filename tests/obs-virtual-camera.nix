# Prove the virtual camera of modules/obs.nix in a VM:
#
#   - the loopback device exists at its fixed number, with its label
#   - it offers no capture while nothing writes to it
#   - a V4L2 reader, as Chromium is, gets frames while a producer writes
#   - OBS has its V4L2 plugin, which holds the virtual camera output
#
# ffmpeg stands in for OBS as the producer. OBS writes to the same device
# through the same V4L2 output interface, and needs a display to run.
{
  pkgs,
  obs,
  device,
  label,
}:
pkgs.testers.runNixOSTest {
  name = "obs-virtual-camera";
  nodes.machine = {
    imports = [ obs ];
    mountainous.features.obs.enable = true;
    environment.systemPackages = [
      pkgs.ffmpeg
      pkgs.v4l-utils
    ];
  };
  testScript =
    { nodes, ... }:
    let
      obsPackage = nodes.machine.programs.obs-studio.finalPackage;
    in
    ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the loopback device has its number and label"):
          info = machine.succeed("v4l2-ctl -d ${device} --info")
          assert "Card type        : ${label}" in info, info

      with subtest("no capture while nothing writes"):
          caps = machine.succeed("v4l2-ctl -d ${device} --info | sed -n '/Device Caps/,$p'")
          assert "Video Capture" not in caps, caps

      with subtest("a V4L2 reader gets frames while a producer writes"):
          machine.succeed(
              "systemd-run --unit=producer ffmpeg -nostdin -re -f lavfi "
              "-i testsrc=size=640x480:rate=30 -pix_fmt yuv420p -f v4l2 ${device}"
          )
          machine.wait_until_succeeds(
              "v4l2-ctl -d ${device} --info | sed -n '/Device Caps/,$p' | grep -q 'Video Capture'"
          )
          machine.succeed(
              "ffmpeg -nostdin -f v4l2 -i ${device} -frames:v 10 -f null - 2>&1"
          )
          machine.succeed("systemctl stop producer")

      with subtest("OBS has its V4L2 plugin"):
          machine.succeed("test -e ${obsPackage}/lib/obs-plugins/linux-v4l2.so")
    '';
}
