{
  config,
  pkgs,
  ...
}: {
  home.shellAliases = {
    lt = "eza -lT";
    lat = "eza -laT";
    ll = "eza --long --header --git";
    ls = "eza";
    l = "eza -l";
    la = "eza -la";
  };

  home.packages = [
    pkgs.eza
  ];
}
