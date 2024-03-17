{
  description = "My NixOS configuration";

  inputs = {
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    # nix-gaming.url = "github:fufexan/nix-gaming";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";
    hardware.url = "github:nixos/nixos-hardware";
    nix-colors.url = "github:misterio77/nix-colors";
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-23.11";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-23.11";
    };

    # My Apps
    # cuttlefish.url = "https://flakehub.com/f/simonwjackson/cuttlefi.sh/*.tar.gz";
    gamerack.url = "https://flakehub.com/f/simonwjackson/gamerack/*.tar.gz";
  };

  outputs = {
    hardware,
    home-manager,
    nixpkgs,
    self,
    ...
  } @ inputs: let
    inherit (self) outputs;
    lib = nixpkgs.lib // home-manager.lib;
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    pkgsFor = lib.genAttrs systems (system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
    rootPath = ./.;
    mkSystem = hostName: system: extraModules:
      lib.nixosSystem {
        specialArgs = {inherit inputs outputs rootPath self;};
        modules =
          [
            (./nixos/hosts + "/${hostName}")
            inputs.agenix.nixosModules.default
            inputs.nix-flatpak.nixosModules.nix-flatpak
            inputs.simple-nixos-mailserver.nixosModule
            inputs.gamerack.nixosModules."${system}".default
            # inputs.cuttlefish.nixosModules."${system}".default
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import (./home-manager/users/simonwjackson/hosts + "/${hostName}");
              home-manager.extraSpecialArgs = {inherit inputs outputs rootPath self;};
            }
          ]
          ++ extraModules;
      };
  in {
    inherit lib;

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = let
      moduleFiles =
        lib.filterAttrs
        (name: type: type == "regular" && builtins.match ".*\\.nix" name != null)
        (builtins.readDir ./nixos/modules);
      modules = lib.mapAttrs (name: value: import (./nixos/modules + "/${name}")) moduleFiles;
    in
      modules;

    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./home-manager/modules;

    # Your custom packages and modifications, exported as overlays
    overlays = import ./nix/overlays {inherit inputs outputs;};

    # Your custom packages
    # Acessible through 'nix build', 'nix shell', etc
    packages = lib.genAttrs systems (system: import ./nix/pkgs {pkgs = pkgsFor.${system};});

    devShells = lib.genAttrs systems (system: import ./shell.nix {pkgs = pkgsFor.${system};});

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = lib.genAttrs systems (system: pkgsFor.${system}.alejandra);

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild <action> --flake .#your-hostname'
    nixosConfigurations = {
      # GPD Win Mini
      kita = mkSystem "kita" "x86_64-linux" [];

      # Main laptop
      fiji = mkSystem "fiji" "x86_64-linux" [];

      # Remote Server
      yabashi = mkSystem "yabashi" "x86_64-linux" [];

      # Home Server
      unzen = mkSystem "unzen" "x86_64-linux" [];

      # router
      rakku = mkSystem "rakku" "x86_64-linux" [];

      # portable gaming rig
    };
  };
}
