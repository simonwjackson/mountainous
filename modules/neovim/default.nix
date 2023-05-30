{ lib, config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    home.packages = with pkgs; [
      neovim-remote
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
        # Language Servers
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted
        # nodePackages.vim-language-server
        # nodePackages.eslint_d
        # nodePackages.typescript
        # jsonnet-language-server
        sumneko-lua-language-server
      ] ++ [
    # nix
        nil
        nixpkgs-fmt
      ] ++ [
        # shell scripting
        nodePackages.bash-language-server
        shellcheck
        shfmt
      ] ++ [
        neovim-remote
        ripgrep
        # xclip
        lf
        # luaformatter
        gh
        taskwarrior
        clang-tools
        deno
        stylua
        nodePackages_latest.prettier
        zig
        nodejs
      ];

      plugins = with pkgs.vimPlugins; [ ];
    };
  };
}
