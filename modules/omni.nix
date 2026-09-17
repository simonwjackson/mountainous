# The omni bar: one field that runs every command.
# Kamoi Super+P command runner, window switcher, and navigation bar.
# Instantiated by shell.qml in quickshell.
{
  nixos.modules.desktop = {
    hjem.users.simon.files.".config/quickshell/mountainous/OmniBar.qml".source =
      ./quickshell/OmniBar.qml;
  };
}
