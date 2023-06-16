{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    home.packages = with pkgs; [
      unzip
      neovim-remote
      xclip
    ];

    home = {
      shellAliases = {
        nvim = "nvim --listen /tmp/nvimsocket";
      };
    };

    home.file = {
      "./.config/nvim" = {
        recursive = true;
        source = ./config;
      };
    };

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraPython3Packages = (ps: with ps; [
        six
        packaging
        tasklib
      ]);

      extraPackages = with pkgs; [
        # nix
        nil
        nixpkgs-fmt
      ] ++ [
        # Shell
        nodePackages.bash-language-server
        shellcheck
        shfmt
      ] ++ [
        # Lua
        sumneko-lua-language-server
        stylua
      ] ++ [
        # JS
        nodePackages_latest.prettier
        deno
        nodejs
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted
      ] ++ [
        # misc
        neovim-remote
        ripgrep
        # xclip
        lf
        # luaformatter
        gh
        taskwarrior
        clang-tools
        zig
      ];

      # plugins = with pkgs.vimPlugins; [ ];
    };
  };
}
