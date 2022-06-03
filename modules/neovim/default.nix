{ lib, config, pkgs, ... }:

{
  imports = [ ];

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
      sha256 = "1sy53l1adzcx802lb7nxbi44sgbi04w5adg248llwqmxdkzamibw";
    }))
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {

    shellAliases = {
      nvim = "nvim --listen /tmp/nvimsocket";
      # BUG: remove this when nvr package gets linked properly
      nvr = "/nix/store/dxgx43vdrgmfqkcrjyfznpg8mhhi54mc-neovim-remote-2.4.0/bin/nvr";
    };

    file = {
      "./.config/nvim/lua" = {
        recursive = true;
        source = ./lua;
      };

      # "./.config/nvim/init.lua" = {
      #   source = ./lua/init.lua;
      # };
    };
  };

  programs.neovim = {
    enable = true;

    extraPackages = with pkgs; [
      ripgrep
      nodePackages.npm
      nodejs
      lf
      rnix-lsp
      sumneko-lua-language-server
      go-langserver
      luaformatter
      neovim-remote
      # haskell-language-server
      # dhall-lsp-server
      # used to compile tree-sitter grammar
      tree-sitter
    ];

    plugins = with pkgs.vimPlugins; [
      vim-nix
      vim-qml
      which-key-nvim
      git-blame-nvim
      yankring # Yank across terminals
      is-vim # Automatically clear search highlights after you move your cursor.
      vim-fugitive

      # COC
      coc-lua

      vim-easy-align # A simple, easy-to-use Vim alignment plugin.
      vim-repeat # Add repeat support to plugins

      # ----------------------------------------------------------------------------
      #  - Extras
      # ----------------------------------------------------------------------------

      nvim-lspconfig
      lush-nvim
    ];

    extraConfig = builtins.concatStringsSep "\n" [
      (lib.strings.fileContents ./vimrc.vim)
      ''
        lua << EOF
        ${lib.strings.fileContents ./vimrc.lua}
        EOF
      ''
    ];

    coc = {
      enable = true;

      package = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "coc.nvim";
        version = "2022-05-21";
        src = pkgs.fetchFromGitHub {
          owner = "neoclide";
          repo = "coc.nvim";
          rev = "791c9f673b882768486450e73d8bda10e391401d";
          sha256 = "sha256-MobgwhFQ1Ld7pFknsurSFAsN5v+vGbEFojTAYD/kI9c=";
        };
        meta.homepage = "https://github.com/neoclide/coc.nvim/";
      };

      pluginConfig = ''
        let g:coc_global_extensions = [
          \ 'coc-react-refactor',
          \ 'coc-python',
          \ 'coc-coverage',
          \ 'coc-css',
          \ 'coc-eslint',
          \ 'coc-explorer',
          \ 'coc-fzf-preview',
          \ 'coc-html',
          \ 'coc-json',
          \ 'coc-sh',
          \ 'coc-snippets',
          \ 'coc-tsserver',
          \ 'coc-vimlsp',
          \ 'coc-yaml',
          \ 'https://github.com/rodrigore/coc-tailwind-intellisense',
          \ "coc-vetur"
          \ ]
      '';
      # \ 'coc-prettier',

      settings = {
        coc.preferences.formatOnSaveFiletypes = [
          #   "javascript"
          #   "typescript"
          #   "typescriptreact"
          #   "javascriptreact"
          "json"
          "elm"
          "css"
          "Markdown"
          "nix"
        ];
        #eslint.filetypes = [ "javascript" "typescript" "typescriptreact" "javascriptreact" ];
        coc.preferences.codeLens.enable = true;
        coc.preferences.currentFunctionSymbolAutoUpdate = true;
        coverage.uncoveredSign.text = "▌";
        diagnostic.errorSign = "▌";
        diagnostic.warningSign = "▌";
        diagnostic.infoSign = "▌";
        explorer.width = 30;
        explorer.icon.enableNerdfont = true;
        explorer.previewAction.onHover = false;
        explorer.keyMappings.global = {
          "<cr>" = [ "expandable?" "expand" "open" ];
          "v" = "open:vsplit";
        };
        languageserver = {
          nix = {
            command = "rnix-lsp";
            filetypes = [ "nix" ];
          };

          "dhall" = {
            "command" = "dhall-lsp-server";
            "filetypes" = [ "dhall" ];
          };

          elm = {
            command = "elm-language-server";
            filetypes = [ "elm" ];
            rootPatterns = [ "elm.json" ];
          };

          # haskell = {
          #   command = "haskell-language-server-wrapper";
          #   args = [ "--lsp" ];
          #   rootPatterns = [
          #     "stack.yaml"
          #     "hie.yaml"
          #     ".hie-bios"
          #     "BUILD.bazel"
          #     ".cabal"
          #     "cabal.project"
          #     "package.yaml"
          #   ];
          #   filetypes = [ "hs" "lhs" "haskell" ];
          # };

          rescript = {
            enable = true;
            module = "~/.local/share/nvim/plugged/vim-rescript/server/out/server.js";
            args = [ "--node-ipc" ];
            filetypes = [ "rescript" ];
            rootPatterns = [ "bsconfig.json" ];
          };

          golang = {
            command = "go-langserver";
            filetypes = [ "go" ];
            initializationOptions = {
              gocodeCompletionEnabled = true;
              diagnosticsEnabled = true;
              lintTool = "golint";
            };
          };

          lua = {
            command = "lua-language-server";
            rootPatterns = [ ".git" ];
            filetypes = [ "lua" ];
          };

        };
      };
    };
  };
}
