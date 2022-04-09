{ lib, config, pkgs, ... }:

{
  imports = [

  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    sessionVariables = { };
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
      haskell-language-server
      dhall-lsp-server
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
      (lib.strings.fileContents ./init.vim)
      ''
        lua << EOF
        ${lib.strings.fileContents ./lua/init.lua}
        EOF
      ''
    ];

    coc = {
      enable = true;

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
          \ 'coc-prettier',
          \ 'coc-sh',
          \ 'coc-snippets',
          \ 'coc-tsserver',
          \ 'coc-vimlsp',
          \ 'coc-yaml',
          \ 'https://github.com/rodrigore/coc-tailwind-intellisense',
          \ ]
      '';

      settings = {
        coc.preferences.formatOnSaveFiletypes = [
          "elm"
          "javascript"
          "typescript"
          "typescriptreact"
          "json"
          "javascriptreact"
          "css"
          "Markdown"
          "nix"
        ];
        eslint.filetypes = [ "javascript" "typescript" "typescriptreact" "javascriptreact" ];
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

          haskell = {
            command = "haskell-language-server-wrapper";
            args = [ "--lsp" ];
            rootPatterns = [
              "stack.yaml"
              "hie.yaml"
              ".hie-bios"
              "BUILD.bazel"
              ".cabal"
              "cabal.project"
              "package.yaml"
            ];
            filetypes = [ "hs" "lhs" "haskell" ];
          };

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
