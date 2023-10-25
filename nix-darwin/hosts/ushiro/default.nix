{pkgs, ...}: {
  imports = [
    ../../common.nix
  ];
  users.users.sjackson217 = {
    name = "sjackson217";
    home = "/Users/sjackson217";
  };

  environment.systemPackages = with pkgs; [
    kitty
  ];

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
