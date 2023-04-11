 Media Control

This NixOS module provides a media control script that allows you to control media playback for various applications using media keys on your keyboard. The supported applications include Music Player Daemon (mpd), mpv, and Firefox.

## Installation

To install this module, add the following to your `configuration.nix`:

```nix
{
  imports = [
    ./path/to/media-control/default.nix
  ];

  programs.media-control.enable = true;
}
```

Make sure to replace `./path/to/media-control` with the actual path to the `media-control` directory.

## Configuration

This module requires the `MPV_SOCKET` environment variable to be set in `home.sessionVariables`. Add the following to your `configuration.nix`:

```nix
{
  home.sessionVariables = {
    MPV_SOCKET = "/path/to/mpv/socket";
  };
}
```

Replace `/path/to/mpv/socket` with the actual path to the mpv socket file.

## Usage

Once the module is installed and configured, you can use the media keys on your keyboard to control media playback for the supported applications. The following keys are supported:

- `XF86AudioPlay`: Play/Pause
- `XF86AudioNext`: Next track
- `XF86AudioPrev`: Previous track

The media control script will automatically detect which application is currently playing audio and send the appropriate command to control the playback. If no supported application is found playing audio, the script will output "No matching application found playing audio."
