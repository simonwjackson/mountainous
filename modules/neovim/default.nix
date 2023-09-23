{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
  generate-tasks-next-markdown = pkgs.writeShellScriptBin "generate-tasks-next-markdown" ''
    set -euo pipefail

    MARKDOWN_FILE="$HOME/documents/notes/NEXT.md"
    
    projects=$(task +PENDING export |  jq -r '.[] | select(.project != null) | .project' | sort | uniq)
    
    for project in $projects
    do
        output+="###### $project | project.is:$project project:$project ((+UNBLOCKED +PENDING) or (+WAITING +UNBLOCKED)) "
        output+='$U'
        output+="\n\n"
    done
    
    touch "$MARKDOWN_FILE"
    echo -e "$output" > "$MARKDOWN_FILE" && \
    nvim --headless -n -c "edit $MARKDOWN_FILE" -c "write" -c "quitall"
  '';

  generate-tasks-review-markdown = pkgs.writeShellScriptBin "generate-tasks-review-markdown" ''
    set -euo pipefail

    REVIEW_FILE="$HOME/documents/notes/REVIEW.md"
    
    output=""
    projects=$(${pkgs.taskwarrior}/bin/task +PENDING export |  jq -r '.[] | select(.project != null) | .project' | sort | uniq)
    
    output+="###### No Project | +PENDING project:"" \n\n"

    output+="###### Due | +PENDING +ai \n\n"
    
    output+="###### AI Review | +PENDING +ai \n\n"
    
    for project in $projects
    do
        output+="###### $project | project.is:$project project:$project\n\n"
    done
    
    completed_projects=$(${pkgs.taskwarrior}/bin/task -PENDING export |  jq -r '.[] | select(.project != null) | .project' | sort | uniq)
    
    output+="###### Completed\n\n"
    
    for project in $completed_projects
    do
        output+="###### $project || project.is:$project project:$project\n\n"
    done
    
    touch "$REVIEW_FILE"
    echo -e "$output" > "$REVIEW_FILE" && \
    ${pkgs.neovim}/bin/nvim --headless -n -c "edit $REVIEW_FILE" -c "write" -c "quitall"
  '';
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
    ] ++ [
      generate-tasks-review-markdown
      generate-tasks-next-markdown
    ];
    
    nixpkgs.overlays = [
      (import (builtins.fetchTarball {
        url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
      }))
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
        pynvim
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
	      luajitPackages.luacheck
        sumneko-lua-language-server
        stylua
      ] ++ [
        # JS
        nodePackages_latest.prettier
        deno
        nodejs
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted
        bun
        deno
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
	      cargo
      ];

      # plugins = with pkgs.vimPlugins; [ ];
    };
  };
}
