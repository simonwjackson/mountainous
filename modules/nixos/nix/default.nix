{...}: {
  config = {
    # Allow unfree packages
    # nixpkgs.config.allowUnfree = true;
    nix.settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
      # Add cachix binary cache
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://simonwjackson.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "simonwjackson.cachix.org-1:MtG0AE8J6bjFO/wD04X5h8MlQh7Sbee8KAJrAsPJydI="
      ];
      auto-optimise-store = true;
    };
    # nix.gc = {
    #   automatic = true;
    #   dates = "weekly";
    # };
  };
}
