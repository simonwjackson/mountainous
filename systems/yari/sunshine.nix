{ config, lib, pkgs, modulesPath, ... }: {
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
  '';

  environment.systemPackages = [
    pkgs.sunshine
  ];

  # security.wrappers.sunshine = {
  #   source = "${pkgs.sunshine}/bin/sunshine";
  #   capabilities = "cap_sys_admin+p";
  #   owner = "root";
  #   group = "root";
  #   permissions = "u+rx,g+rx";
  # };
}
