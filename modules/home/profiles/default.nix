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

  options.mountainous.profiles.workstation = {
    enable = mkEnableOption "Enable workstation";
  };

  config = mkIf config.mountainous.profiles.workstation.enable {
    mountainous = {
      agenix = mkDefault enabled;
      atuin = {
        enable = true;
        key_path = config.age.secrets.atuin_key.path;
        session_path = config.age.secrets.atuin_session.path;
      };
      bat = mkDefault enabled;
      direnv = mkDefault enabled;
      desktops.hyprland = mkDefault enabled;
      eza = mkDefault enabled;
      firefox = mkDefault enabled;
      git = {
        enable = mkDefault true;
        github-token = config.age.secrets."user-simonwjackson-github-token".path;
      };
      kitty = mkDefault enabled;
      lf = mkDefault enabled;
      mpvd = mkDefault enabled;
      secure-shell = mkDefault enabled;
      tridactyl = mkDefault enabled;
      work-mode = mkDefault disabled;
      xpo = mkDefault enabled;
      zsh = mkDefault enabled;
      tank = {
        enable = mkDefault false;
        path = mkDefault "/glacier/snowscape/";
      };
      taskwarrior-sync = {
        enable = mkDefault false;
        publicCertFile = config.age.secrets."user-simonwjackson-taskserver-public.cert".path;
        privateKeyFile = config.age.secrets."user-simonwjackson-taskserver-private.key".path;
        caCertFile = config.age.secrets."user-simonwjackson-taskserver-ca.cert".path;
        server = "yari:53589";
        credentials = "backpacker/simonwjackson/430e9d17-bc5e-4534-9c37-c1dcab337dbe";
      };
    };

    home = {
      pointerCursor = {
        package = pkgs.catppuccin-cursors.frappeBlue;
        name = "Catppuccin-Frappe-Blue-Cursors";
        size = 24; # Adjust size as needed
        gtk.enable = true;
        x11.enable = true;
      };
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
        wl-clipboard
      ];
    };

    programs.bash.enable = true;
    programs.bash.enableCompletion = true;

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";
  };
}
