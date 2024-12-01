{pkgs}:
pkgs.writeShellApplication {
  name = "gamescope-reaper";

  runtimeInputs = with pkgs; [
    coreutils
    gawk
    procps
    findutils
    gum
  ];

  text = builtins.readFile ./child-process-monitor.sh;
}
