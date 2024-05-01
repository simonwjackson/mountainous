{
  pkgs,
  inputs,
  ...
}: {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    kitty
    yarn
    nodejs_20
    python3
  ];

  programs.myNeovim = {
    enable = true;
    environment = {
      NOTES_DIR = "/Users/sjackson217/notes";
    };
    environmentFiles = [
      # config.age.secrets."user-simonwjackson-anthropic".path
    ];
  };
  environment.etc = {
    "sudoers.d/10-nix-commands".text = let
      commands = [
        "/run/current-system/sw/bin/darwin-rebuild"
        "/run/current-system/sw/bin/nix*"
        "/run/current-system/sw/bin/ln"
        "/nix/store/*/activate"
        "/bin/launchctl"
      ];
      commandsString = builtins.concatStringsSep ", " commands;
    in ''
      %admin ALL=(ALL:ALL) NOPASSWD: ${commandsString}
    '';
  };

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  services.karabiner-elements.enable = true;
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnsupportedSystem = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.sjackson217 = {
    name = "sjackson217";
    home = "/Users/sjackson217";
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
