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
      lf
      luaformatter
      tree-sitter
    ];

    # TODO: Checkout these plugins
    # https://github.com/rockerBOO/awesome-neovim/blob/main/README.md
    # https://github.com/kdheepak/lazygit.nvim
    # https://github.com/rest-nvim/rest.nvim#features
    # https://github.com/glacambre/firenvim Give it another try, integrates neovim into firefox
    # https://github.com/sindrets/diffview.nvim
    # https://github.com/akinsho/git-conflict.nvim
    # https://github.com/weilbith/nvim-code-action-menu
    # https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#tailwindcss
    # https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#marksman
    # https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#prosemd_lsp
    # https://github.com/Equilibris/nx.nvim
    # https://github.com/pwntester/octo.nvim
    plugins = with pkgs.vimPlugins; [
      copilot-lua

      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/gitsigns.lua);
      }

      # A personal wiki for Vim 
      {
        plugin = vimwiki;
        type = "viml";
        config = builtins.readFile (./plugins/vimwiki.vim);
      }

      vim-floaterm
      toggleterm-nvim

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
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = builtins.readFile (./plugins/treesitter.lua);
      }


      plenary-nvim

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

      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = builtins.readFile (./plugins/lspconfig.lua);
      }

      # Unsure how to configure this. Formatting is working without this plugin
      # {
      #   plugin = lsp-format-nvim;
      #   type = "lua";
      #   config = builtins.readFile (./plugins/lsp-format.lua);
      # }

      {
        plugin = dressing-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/dressing.lua);
      }

      {
        plugin = hop-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/hop.lua);
      }

      {
        plugin = zen-mode-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/zen-mode.lua);
      }

      {
        plugin = twilight-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/twilight.lua);
      }

      {
        plugin = noice-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/noice.lua);
      }

      nvim-ts-context-commentstring
      {
        plugin = comment-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/comment.lua);
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
      luasnip

      {
        plugin = nvim-cmp;
        type = "lua";
        config = builtins.readFile (./plugins/cmp.lua);
      }

      editorconfig-nvim

      {
        plugin = null-ls-nvim;
        type = "lua";
        config = builtins.readFile (./plugins/null-ls.lua);
      }

      {
        plugin = goto-preview;
        type = "lua";
        config = builtins.readFile (./plugins/goto-preview.lua);
      }

      # vim-qml

      # git-blame-nvim
      # yankring # Yank across terminals
      # is-vim # Automatically clear search highlights after you move your cursor.
      # vim-fugitive

      # vim-easy-align # A simple, easy-to-use Vim alignment plugin.
      # vim-repeat # Add repeat support to plugins

      # ----------------------------------------------------------------------------
      #  - Extras
      # ----------------------------------------------------------------------------

      # lush-nvim
    ];

    extraConfig = builtins.readFile ./vimrc.vim;

    coc = {
      enable = false;

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
        \ 'coc-vimlsp',
        \ 'coc-yaml',
        \ 'https://github.com/rodrigore/coc-tailwind-intellisense',
        \ ]
      '';
      # \ 'coc-prettier',
      # \ 'coc-tsserver',

      settings = {
        coc.preferences.formatOnSaveFiletypes = [
          #"javascript"
          #"javascriptreact"
          "json"
          "elm"
          "css"
          "Markdown"
          "nix"
        ];
        # eslint.filetypes = [ "javascript" "typescript" "typescriptreact" "javascriptreact" ];
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
