{ config, lib, ... }:

{
  programs.taskwarrior.config = lib.mkMerge [{
    taskd.certificate = "${config.home.homeDirectory}/.local/share/task/keys/public.cert";
    taskd.key = "${config.home.homeDirectory}/.local/share/task/keys/private.key";
    taskd.ca = "${config.home.homeDirectory}/.local/share/task/keys/ca.cert";
    taskd.credentials = builtins.getEnv "TASKD_CREDENTIALS";
    taskd.server = builtins.getEnv "TASKD_SERVER";
  }];
}
