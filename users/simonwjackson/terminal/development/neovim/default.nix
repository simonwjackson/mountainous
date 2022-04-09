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
      # # ----------------------------
      # #  - Theems
      # # ----------------------------

      # # Plastic
      # #(plugin "flrnprz/plastic.vim")

      # # ----------------------------
      # #  - Syntax
      # # ----------------------------

      # vim-nix
      # #vim-go
      # vim-elm-syntax
      # vim-git
      # vim-qml
      # #(plugin "rescript-lang/vim-rescript")

      # vim-jsx-pretty # The React syntax highlighting and indenting plugin for vim. Also supports the typescript tsx file.
      # # Typescript
      # typescript-vim
      # vim-jsx-typescript

      # vim-json # Distinct highlighting of keywords vs values, JSON-specific (non-JS) warnings, quote concealing.
      # jsonc-vim # JSONC (with comments)
      # vim-graphql # A Vim plugin that provides GraphQL file detection, syntax highlighting, and indentation.

      # # ----------------------------
      # #  - Other
      # # ----------------------------

      # which-key-nvim
      # git-blame-nvim
      # yankring # Yank across terminals
      # vim-surround # quoting/parenthesizing made simple
      # vim-gitgutter # A Vim plugin which shows a git diff in the gutter (sign column) and stages/undoes hunks and partial hunks.
      # is-vim # Automatically clear search highlights after you move your cursor.
      # taskwiki # Proper project management in vim.
      # vimwiki # A personal wiki for Vim 
      # vim-tmux-navigator # Seamless navigation between tmux panes and vim splits
      # vim-eunuch # Vim sugar for the UNIX shell commands that need it the most
      # vim-multiple-cursors # True Sublime Text style multiple selections for Vim
      # lightline-vim # A light and configurable statusline/tabline plugin for Vim http

      # # Adds file type icons to Vim plugins
      # vim-devicons
      # nvim-web-devicons

      # limelight-vim # Hyperfocus-writing in Vim.
      # goyo-vim # Distraction-free writing in Vim
      # ##### vim-windowswap # Swap windows without ruining your layout!
      # todo-comments-nvim # Todo Comments
      # lazygit-nvim # LazyGit
      # trouble-nvim # Trouble
      # ##### octo-nvim # Edit and review GitHub issues and pull requests
      # vim-obsession # continuously updated session files 
      # vim-rooter # Changes Vim working directory to project root. 
      # vim-easymotion # Vim motions on speed!
      # vim-expand-region # expand region (+/-)
      # ultisnips # Ultisnips: Text Expansion
      # vimspector # A multi-language debugging system for Vim 

      # # VIM Test
      # vim-test
      # vim-ultest

      # # Telescope
      # telescope-nvim
      # telescope-coc-nvim
      # plenary-nvim
      # popup-nvim

      # vim-fugitive
      # nerdcommenter

      # vim-asterisk # Improved * motions
      # vim-highlightedyank # Briefly highlight which text was yanked.
      # vim-tmux-focus-events # FocusGained and FocusLost for vim inside Tmux
      # lf-vim # LF file browser

      # # COC
      # coc-lua
      # coc-yaml
      # coc-python
      # coc-css
      # coc-eslint
      # coc-explorer
      # coc-html
      # coc-json
      # coc-prettier
      # coc-snippets
      # coc-tsserver
      # coc-vimlsp

      # # (plugin "Glench/Vim-Jinja2-Syntax") # Jinja2
      # # (plugin "tpope/vim-cucumber") # Cucumber
      # # (plugin "jxnblk/vim-mdx-js") # MDX
      # # (plugin "ekalinin/dockerfile.vim") # Docker
      # # (plugin "yuezk/vim-js") # A Vim syntax highlighting plugin for JavaScript and Flow.js
      # # (plugin "nelstrom/vim-visual-star-search") # Modify * to also work with visual selections.
      # vim-easy-align # A simple, easy-to-use Vim alignment plugin.
      # vim-repeat # Add repeat support to plugins

      # # ----------------------------------------------------------------------------
      # #  - Extras
      # # ----------------------------------------------------------------------------

      # # fzf for vim
      # #(plugin "junegunn/fzf")
      # #(plugin "junegunn/fzf.vim")

      # # Modify * to also work with visual selections.
      # #(plugin "nelstrom/vim-visual-star-search")

      # # An eye friendly plugin that fades your inactive buffers and preserves your syntax highlighting!
      # # (plugin "TaDaa/vimade")

      # # For lf
      # #(plugin "voldikss/vim-floaterm")

      # # Taskwarrior in VIM
      # # (plugin "farseer90718/vim-taskwarrior")

      # # Zettelkasten for VIM
      # #(plugin "michal-h21/vim-zettel")

      # # Auto Sessions
      # # (plugin "rmagatti/auto-session")
      # # (plugin "rmagatti/session-lens")

      # #(plugin "github/copilot.vim") # AI pair programmer

      # #(plugin "dhruvasagar/vim-zoom")
      # #(plugin "camgraff/telescope-tmux.nvim")
      # #(plugin "RyanMillerC/better-vim-tmux-resizer")

      # #(plugin "lukas-reineke/lsp-format.nvim")
      # nvim-lspconfig
      # lush-nvim
      # multiple-cursors # Multiple cursors selection, etc
    ];

    # extraConfig = "lua require('init')";

    extraConfig = builtins.concatStringsSep "\n" [
      (lib.strings.fileContents ./config.vim)
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
