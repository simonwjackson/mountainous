{ lib, config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    imports = [ ];

    home.packages = with pkgs; [
      nodejs-16_x
      bun
      # deno
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

      extraPython3Packages = (ps: with ps; [
        six
        packaging
        tasklib
      ]);

      extraPackages = with pkgs; [
        # Language Servers
        nil
        nixpkgs-fmt
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted
        nodePackages.vim-language-server
        nodePackages.bash-language-server
        nodePackages.eslint_d
        nodePackages.typescript
        jsonnet-language-server
        sumneko-lua-language-server
        rnix-lsp
        shellcheck

        neovim-remote
        ripgrep
        xclip
        lf
        luaformatter
        tree-sitter
        gh

        taskwarrior
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

      # https://github.com/anuvyklack/hydra.nvim
      # https://github.com/kiyoon/telescope-insert-path.nvim

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
  };
}
