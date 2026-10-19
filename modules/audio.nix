# Which speaker and which microphone a desktop uses, as one fixed ranking.
#
# WirePlumber's own policy depends on history. It stores every device that
# was ever chosen, restores the newest one that is present, and lets a manual
# choice outrank everything for good. The result depends on what was clicked
# last, not on what is connected. Here the ranking below decides. A manual
# choice in the sound panel still works, but only until a device is connected
# or removed. Then the ranking decides again.
#
# Ranking, highest first. A larger priority.session wins.
#
#   Speakers                                Microphones
#   3000 headphones in the jack             2200 Shure X2u (XLR adapter)
#   2900 Bluetooth headphones               2109 other USB microphone or headset
#   2800 other USB output (headset, DAC)    2050 headset microphone in the jack
#   2000 Audioengine 2+ desk speakers       2010 Bluetooth microphone (fixed
#   1000 built-in speakers                       by WirePlumber, see below)
#    400 Saramonic BTW receiver             1900 webcam microphone
#                                           1600 built-in microphones
#
# HDMI and DisplayPort outputs do not appear at all. On the Galaxy Book3 the
# galaxy-book3 layer removes them from the sound card's UCM profile. The
# Shure X2u's monitor jack does not appear either; see its rule below.
#
# WirePlumber gives every Bluetooth microphone priority 2010 in code
# (monitors/bluez/create-loopback-node.lua), and no rule can change it. The
# other microphone priorities are placed around that fixed value.
#
# Measured on Myoko, 2026-10-18, with `wpctl status` and `pw-dump`.
{ lib, ... }:
let
  module =
    { ... }:
    let
      priority = value: { "priority.session" = value; };
      rule = matches: actions: { inherit matches actions; };
    in
    {
      services.pipewire.wireplumber.extraConfig."60-mountainous-audio" = {
        # Do not restore stored default devices or stored profiles: both are
        # history. Volumes per device (routes) and per application (streams)
        # are still remembered.
        "wireplumber.profiles".main = {
          "hooks.default-nodes.state" = "disabled";
          "hooks.device.profile.state" = "disabled";
          "custom.forget-manual-default" = "required";
        };

        "wireplumber.components" = [
          {
            name = "mountainous/forget-manual-default.lua";
            type = "script/lua";
            provides = "custom.forget-manual-default";
          }
        ];

        # Later rules override earlier ones, so general rules come first.
        "monitor.alsa.rules" = [
          (rule [ { "node.name" = "~alsa_output.usb-.*"; } ] { update-props = priority 2800; })
          (rule [ { "node.name" = "~alsa_input.usb-.*"; } ] { update-props = priority 2109; })
          (rule [ { "node.name" = "~alsa_input.*"; "device.form-factor" = "webcam"; } ] {
            update-props = priority 1900;
          })

          # The internal card. UCM splits the jack and the speakers into two
          # profiles, so the Headphones node exists only while the jack holds
          # a plug.
          (rule [ { "node.name" = "~alsa_output.*HiFi__Headphones__sink"; } ] { update-props = priority 3000; })
          (rule [ { "node.name" = "~alsa_output.*HiFi__Speaker__sink"; } ] { update-props = priority 1000; })
          (rule [ { "node.name" = "~alsa_input.*HiFi__Mic2__source"; } ] { update-props = priority 2050; })
          (rule [ { "node.name" = "~alsa_input.*HiFi__Mic1__source"; } ] { update-props = priority 1600; })

          # Audioengine 2+ desk speakers. Their USB IDs collide with an Mpow
          # headset in the USB ID database, so without this they show up as
          # "Mpow HC5 Headset in charging mode", with form factor headset.
          (rule [ { "device.name" = "~alsa_card.usb-Audioengine_LLC_Audioengine_2_.*"; } ] {
            update-props = {
              "device.description" = "Audioengine 2+";
              "device.form-factor" = "speaker";
            };
          })
          (rule [ { "node.name" = "~alsa_output.usb-Audioengine_LLC_Audioengine_2_.*"; } ] {
            update-props = priority 2000 // {
              "node.description" = "Audioengine 2+ Speakers";
              "device.form-factor" = "speaker";
            };
          })

          # Shure X2u: an XLR microphone adapter. Its output is only a monitor
          # jack that is never used, so the output node is not created.
          (rule [ { "node.name" = "~alsa_input.usb-Shure_Incorporated_Shure_Digital-.*"; } ] {
            update-props = priority 2200 // { "node.description" = "Shure X2u Microphone"; };
          })
          (rule [ { "node.name" = "~alsa_output.usb-Shure_Incorporated_Shure_Digital-.*"; } ] {
            update-props = { "node.disabled" = true; };
          })
        ];

        "monitor.bluez.rules" = [
          (rule [ { "node.name" = "~bluez_output.*"; } ] { update-props = priority 2900; })
          # Saramonic BTW: a wireless microphone receiver. It is a microphone,
          # not headphones, so its output never takes the sound.
          (rule [ { "node.name" = "~bluez_output.*"; "api.bluez5.address" = "F4:4E:FC:84:E6:61"; } ] {
            update-props = priority 400;
          })
        ];
      };

      services.pipewire.wireplumber.extraScripts."mountainous/forget-manual-default.lua" =
        builtins.readFile ./audio-forget-manual-default.lua;
    };
in
{
  nixos.modules.desktop = module;

  perSystem =
    { pkgs, system, ... }:
    # The VM test needs KVM, which only the x86_64 machines have.
    lib.mkIf (system == "x86_64-linux") {
      checks.audio-policy = import ../tests/audio-policy.nix {
        inherit pkgs;
        audio = module;
      };
    };
}
