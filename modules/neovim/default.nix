{ lib, config, pkgs, ... }:

{
  imports = [ ];

  home.packages = with pkgs; [
    nodejs-16_x
    bun
    deno
    neovim-remote
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    shellAliases = {
      nvim = "nvim --listen /tmp/nvimsocket";
    };
  };

  home.file = {
    "./.config/nvim/lua/plugins" = {
      recursive = true;
      source = ./plugins;
    };
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      # Language Servers
      nil
      nixpkgs-fmt
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.vim-language-server
      nodePackages.bash-language-server
      nodePackages.eslint_d
      jsonnet-language-server
      sumneko-lua-language-server
      rnix-lsp
      shellcheck

      nodePackages.typescript
      neovim-remote
      ripgrep
      xclip
      lf
      luaformatter
      tree-sitter
      gh
    ];

    #   extraConfig = ''
    #     lua EOF <<
    #
    # >>
    #   '';

    # TODO: Decide on these
    # Still in beta
    # Give it another try, integrates neovim into firefox
    # https://github.com/glacambre/firenvim

    # https://github.com/ray-x/navigator.lua


    # TODO: Checkout these plugins
    # https://nvchad.com/quickstart/install


    plugins = with pkgs.vimPlugins; [
      {
        plugin = packer-nvim;
        type = "lua";
        config = builtins.readFile ./plugins/packer.lua;
      }

      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = builtins.readFile (./plugins/treesitter.lua);
      }

      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-nvim-lua
      cmp-zsh
      cmp-tmux
      cmp-spell
      cmp-npm
      cmp-emoji
      cmp-copilot
      cmp-cmdline-history
      cmp-cmdline
      cmp_luasnip

      {
        plugin = nvim-cmp;
        type = "lua";
        config = builtins.readFile (./plugins/cmp.lua);
      }
    ];
  };
}
