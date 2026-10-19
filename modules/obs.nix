# OBS Studio, with its program output as a camera that browsers can use.
#
# OBS's "Start Virtual Camera" writes the program output, after every filter,
# to a v4l2loopback device. Chromium reads cameras through V4L2 unless the
# WebRtcPipeWireCamera feature is on, so the device appears in a call's
# camera list as "OBS Virtual Camera". See docs/decisions/obs.md.
{ lib, ... }:
let
  # The loopback device's number. On the Galaxy Book3 the IPU6 takes
  # /dev/video0 to /dev/video31 and USB cameras follow, so the upstream
  # module's video_nr=1 races the IPU6 at boot. 63 is above both.
  videoNr = 63;
  label = "OBS Virtual Camera";

  module =
    { config, lib, ... }:
    let
      cfg = config.mountainous.features.obs;
    in
    {
      options.mountainous.features.obs.enable =
        lib.mkEnableOption "OBS Studio with a virtual camera for browser video calls";

      config = lib.mkIf cfg.enable {
        programs.obs-studio.enable = true;

        # programs.obs-studio.enableVirtualCamera does the same, but with
        # video_nr=1 and the label "OBS Cam". Its modprobe line cannot be
        # overridden, only appended to, so set the module up here instead.
        boot.kernelModules = [ "v4l2loopback" ];
        boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
        # exclusive_caps=1: the device offers capture only while OBS writes
        # to it. Chromium then lists the camera only while OBS sends a
        # picture, never as a black frame.
        boot.extraModprobeConfig = ''
          options v4l2loopback devices=1 video_nr=${toString videoNr} card_label="${label}" exclusive_caps=1
        '';
      };
    };
in
{
  nixos.modules.desktop = module;

  perSystem =
    { pkgs, system, ... }:
    # The VM test needs KVM, which only the x86_64 machines have.
    lib.mkIf (system == "x86_64-linux") {
      checks.obs-virtual-camera = import ../tests/obs-virtual-camera.nix {
        inherit pkgs label;
        obs = module;
        device = "/dev/video${toString videoNr}";
      };
    };
}
