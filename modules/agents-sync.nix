# ~/.agents (shared agent skills) follows pi: every host that syncs pi
# settings, plus Zao, where the folder's Git repository lives. Git history
# stays on Zao; the other hosts receive the working tree only.
{ config, ... }:
{
  mountainous.fleetSync.externalDevices.zao = {
    deviceId = "V5O2ENZ-7SH3MJ3-SXSRIHV-LPLQPRF-WHEDIUA-DXBG2HA-O64K72V-ZURSEQI";
    tailnetName = "zao.hummingbird-lake.ts.net";
  };

  mountainous.fleetSync.folders.agents = {
    hosts = config.mountainous.fleetSync.folders.pi.hosts ++ [ "zao" ];
    path = ".agents";
    ignore = [
      # Every Git file and directory at any depth: .git, .gitignore,
      # .gitattributes, .gitmodules, and nested repositories' .git.
      "(?d).git*"
      "(?d)__pycache__"
      "(?d)node_modules"
      "(?d).DS_Store"
      "*.swp"
      "*~"
    ];
  };
}
