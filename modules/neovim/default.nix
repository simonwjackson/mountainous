{ lib, config, pkgs, ... }:

{
  imports = [ ];

  home.packages = with pkgs; [
    neovide
    nodejs-16_x
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    shellAliases = {
      nvim = "nvim --listen /tmp/nvimsocket";
      # BUG: remove this when nvr package gets linked properly
      nvr = "/nix/store/dxgx43vdrgmfqkcrjyfznpg8mhhi54mc-neovim-remote-2.4.0/bin/nvr";
    };

  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      ripgrep
      lf
      rnix-lsp
      sumneko-lua-language-server
      luaformatter
      neovim-remote
      tree-sitter
    ];

    plugins = with pkgs.vimPlugins; [
      copilot-vim

      # {
      #   plugin = wilder-nvim;
      #   config = builtins.readFile (./plugins/wilder.vim);
      # }

      {
        plugin = telescope-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/telescope.lua);
      }

      {
        plugin = lualine-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/lualine.lua);
      }

      {
        plugin = which-key-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/which-key.lua);
      }

      {
        plugin = todo-comments-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/todo-comments.lua);
      }

      {
        plugin = trouble-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/trouble.lua);
      }

      vim-nix
      # vim-qml

      # git-blame-nvim
      # yankring # Yank across terminals
      # is-vim # Automatically clear search highlights after you move your cursor.
      # vim-fugitive

      # COC
      coc-lua

      # vim-easy-align # A simple, easy-to-use Vim alignment plugin.
      # vim-repeat # Add repeat support to plugins

      # ----------------------------------------------------------------------------
      #  - Extras
      # ----------------------------------------------------------------------------

      # nvim-lspconfig
      # lush-nvim
    ];

    extraConfig = builtins.readFile ./vimrc.vim;

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
          \ 'coc-sh',
          \ 'coc-snippets',
          \ 'coc-tsserver',
          \ 'coc-vimlsp',
          \ 'coc-yaml',
          \ 'https://github.com/rodrigore/coc-tailwind-intellisense',
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

          rescript = {
            enable = true;
            module = "~/.local/share/nvim/plugged/vim-rescript/server/out/server.js";
            args = [ "--node-ipc" ];
            filetypes = [ "rescript" ];
            rootPatterns = [ "bsconfig.json" ];
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
