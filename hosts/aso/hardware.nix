{...}: {
  wsl.enable = true;
  wsl.defaultUser = "nixos";
  wsl.wslConf.network.generateResolvConf = false;
}
