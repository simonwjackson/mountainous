{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    kitty
    yarn
    nodejs_20
    python3
  ];

  programs.icho = {
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
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";
  nix.package = pkgs.nixVersions.latest;

  nixpkgs.config.allowUnsupportedSystem = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  users.users.sjackson217 = {
    name = "sjackson217";
    home = "/Users/sjackson217";
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 4;
}
