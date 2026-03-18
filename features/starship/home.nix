{
  config,
  lib,
  ...
}: let
  cfg = config.mountainous.features.starship;
  transportModule = "\${custom.transport}";
  hostModule =
    if cfg.hostName == null
    then "$hostname"
    else "\${custom.host}";
  hostHash = builtins.hashString "sha256" (if cfg.hostName == null then "localhost" else cfg.hostName);
  brightenHex = c: {
    "0" = "8";
    "1" = "9";
    "2" = "a";
    "3" = "b";
    "4" = "c";
    "5" = "d";
    "6" = "e";
    "7" = "f";
    "8" = "8";
    "9" = "9";
    "a" = "a";
    "b" = "b";
    "c" = "c";
    "d" = "d";
    "e" = "e";
    "f" = "f";
  }.${c};
  hostColor = let
    c = n: brightenHex (builtins.substring n 1 hostHash);
  in "#${c 0}${c 1}${c 2}${c 3}${c 4}${c 5}";
  hostColorStyle = "bold fg:${hostColor}";
in {
  config = lib.mkIf cfg.enable {
    home-manager.users.simonwjackson.programs.starship = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        add_newline = false;
        format = "${transportModule}${hostModule}$directory$git_branch$git_status$nix_shell$character";

        custom.transport = {
          command = "printf '%s' '⇄'";
          when = "test -n \"$MOSH_IP\" || test -n \"$SSH_CONNECTION\"";
          format = "[$output]($style) ";
          style = "bold yellow";
        };

        hostname = {
          ssh_only = false;
          format = "[$hostname]($style) ";
          style = hostColorStyle;
        };

        custom.host = lib.mkIf (cfg.hostName != null) {
          command = "printf '%s' '${cfg.hostName}'";
          when = "true";
          format = "[$output]($style) ";
          style = hostColorStyle;
        };

        directory = {
          truncation_length = 3;
          style = "bold cyan";
        };

        git_branch = {
          format = "[$branch]($style) ";
          style = "bold purple";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          style = "bold red";
        };

        nix_shell = {
          format = "[$symbol$state]($style) ";
          symbol = "❄️ ";
        };

        character = {
          success_symbol = "[›](bold green)";
          error_symbol = "[›](bold red)";
        };
      };
    };
  };
}
