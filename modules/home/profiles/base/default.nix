{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
  inherit (lib) mkDefault mkEnableOption mkIf;
in {
  imports = [
    inputs.agenix.homeManagerModules.age
  ];

  options.mountainous.profiles.base = {
    enable = mkEnableOption "Enable base profile";
  };

  config = mkIf config.mountainous.profiles.base.enable {
    mountainous = {
      agenix = mkDefault enabled;
      atuin = {
        enable = true;
        key_path = config.age.secrets.atuin_key.path;
        session_path = config.age.secrets.atuin_session.path;
      };
      bat = mkDefault enabled;
      eza = mkDefault enabled;
      git = {
        enable = mkDefault true;
        github-token = config.age.secrets."user-simonwjackson-github-token".path;
      };
      lf = mkDefault enabled;
      secure-shell = mkDefault enabled;
      xpo = mkDefault enabled;
      zsh = mkDefault enabled;
    };

    home = {
      sessionVariables = {
        EDITOR = "nvim";
        NIXIE_BUILDERS = "aka,unzen,zao,haku";
        NIXPKGS_ALLOW_UNFREE = 1;
        MOSH_TITLE_NOPREFIX = 1; # Disable mosh banner when there is a stuck process.
      };
      packages = with pkgs; [
        fd
        ripgrep
        lazygit
        jq
        yq-go
      ];
    };

    programs.bash.enable = true;
    programs.bash.enableCompletion = true;

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";
  };
}
