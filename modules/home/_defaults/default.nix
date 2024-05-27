{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
  inherit (lib) mkDefault;
in {
  imports = [
    inputs.backpacker.homeModules.lf
  ];

  config = {
    backpacker = {
      lf = mkDefault enabled;
    };

    mountainous = {
      agenix = mkDefault enabled;
      atuin = {
        enable = true;
        key_path = config.age.secrets.atuin_key.path;
        session_path = config.age.secrets.atuin_session.path;
      };
      bat = mkDefault enabled;
      eza = mkDefault enabled;
      firefox = mkDefault enabled;
      direnv = mkDefault enabled;
      git = {
        enable = mkDefault true;
        github-token = config.age.secrets."user-simonwjackson-github-token".path;
      };
      kitty = mkDefault enabled;
      mpvd = mkDefault enabled;
      secure-shell = mkDefault enabled;
      tank = {
        enable = mkDefault true;
        path = mkDefault "/glacier/snowscape/";
      };
      taskwarrior-sync = {
        enable = mkDefault true;
        publicCertFile = config.age.secrets."user-simonwjackson-taskserver-public.cert".path;
        privateKeyFile = config.age.secrets."user-simonwjackson-taskserver-private.key".path;
        caCertFile = config.age.secrets."user-simonwjackson-taskserver-ca.cert".path;
        server = "yari:53589";
        credentials = "mountainous/simonwjackson/430e9d17-bc5e-4534-9c37-c1dcab337dbe";
      };
      tridactyl = mkDefault enabled;
      work-mode = mkDefault disabled;
      xpo = mkDefault enabled;
      zsh = mkDefault enabled;
    };

    home = {
      sessionVariables = {
        EDITOR = "nvim";
      };
      packages = [
      ];
    };

    programs.bash.enable = true;

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";
  };
}
