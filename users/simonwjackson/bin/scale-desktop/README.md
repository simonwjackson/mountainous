Title: Scale Desktop README

Description:
Scale Desktop is a simple shell application that allows users to easily change the scaling factor of their desktop on Linux/NixOS 23.05 (Stoat) operating system with zsh shell. The application uses xrandr and fzf to provide an interactive interface for selecting the desired scaling factor.

Dependencies:
- xorg.xrandr
- fzf

Installation:
The application is installed as part of the NixOS configuration. Add the provided configuration code to your NixOS configuration file and rebuild your system.

Usage:
1. Run the `scale-desktop` command in your terminal.
2. An interactive list of available scaling factors will be displayed. Use the arrow keys to navigate and press Enter to select the desired scaling factor.
3. The desktop scaling will be updated according to the selected scaling factor.

Note: The selected scaling factor will be saved in the `$HOME/.local/share/desktop/scale` file.
