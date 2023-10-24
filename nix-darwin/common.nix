{ pkgs, ... }: {
  # INFO: nix-darwin switch without password
  # https://github.com/LnL7/nix-darwin/issues/165#issuecomment-829492913
  environment.etc = {
    "sudoers.d/10-nix-commands".text =
      let
        commands = [
          "/run/current-system/sw/bin/darwin-rebuild"
          "/run/current-system/sw/bin/nix*"
          "/run/current-system/sw/bin/ln"
          "/nix/store/*/activate"
          "/bin/launchctl"
        ];
        commandsString = builtins.concatStringsSep ", " commands;
      in
      ''
        %admin ALL=(ALL:ALL) NOPASSWD: ${commandsString}
      '';
  };

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Set Git commit hash for darwin-version.
  # system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
