{ config, pkgs, ... }:

let
  script1 = pkgs.writeShellApplication {
    name = "vimwiki-index";
    runtimeInputs = with pkgs; [ ];
    text = builtins.readFile ./vimwiki-index.sh;
  };

  script2 = pkgs.writeShellApplication {
    name = "vimwiki-inbox";
    runtimeInputs = with pkgs; [ ];
    text = builtins.readFile ./vimwiki-inbox.sh;
  };

  script3 = pkgs.writeShellApplication {
    name = "vimwiki-journal";
    runtimeInputs = with pkgs; [ ];
    text = builtins.readFile ./vimwiki-journal.sh;
  };

  script4 = pkgs.writeShellApplication {
    name = "find-meeting";
    runtimeInputs = with pkgs; [
      ripgrep
    ];
    text = builtins.readFile ./find-meeting.sh;
  };

  script5 = pkgs.writeShellApplication {
    name = "vimwiki-journal-weekly";
    runtimeInputs = with pkgs; [ ];
    text = builtins.readFile ./vimwiki-journal-weekly.sh;
  };

in
{
  home.packages = [
    script1
    script2
    script3
    script4
    script5
  ];
}
