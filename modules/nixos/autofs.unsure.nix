{
  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=60
  '';
}
