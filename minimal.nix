{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
    cache = "none"; # default is "loose"
  };

  # Basic system configuration
  boot.loader.grub.enable = false;
  users.users.root.password = "";
  users.users."nixos".initialPassword = "nixos";

  # Enable SSH for remote access
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

  virtualisation = {
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };

  services.getty.autologinUser = lib.mkForce "nixos";

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    curl
  ];

  system.stateVersion = "24.11"; # Use the appropriate version
}
