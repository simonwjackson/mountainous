# This file (and the global directory) holds config that i use on all hosts
{
  lib,
  inputs,
  outputs,
  pkgs,
  config,
  ...
}: {
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
      ./networking
      ./nix.nix
      ./locale.nix
      ./printing.nix
      ./syncthing.nix
    ]
    ++ (builtins.attrValues outputs.nixosModules);

  home-manager.extraSpecialArgs = {inherit inputs outputs;};

  # services.flatpak.enable = true;
  services.udisks2.enable = true;

  # TODO: Move to (desktop?) profile
  environment.variables.BROWSER = "firefox";

  nixpkgs = {
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications

      # You can also add overlays exported from other flakes:
      inputs.neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    config = {
      allowUnfree = true;
    };
  };

  # environment.enableAllTerminfo = true;

  hardware.enableRedistributableFirmware = true;
  networking.domain = "mountain.ous";

  # $ nix search wget
  # TODO: dont hardcode system type
  environment.systemPackages = [
    inputs.agenix.packages."x86_64-linux".default
  ];

  # Increase open file limit for sudoers
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];

  console = {
    font = lib.mkDefault "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  services.gpm.enable = true; # TTY mouse
}
