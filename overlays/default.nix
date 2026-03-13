[
  (final: prev: {
    vpn-ns = final.callPackage ../pkgs/vpn-ns {};
    gogcli = final.callPackage ../pkgs/gogcli.nix {};
    lifted-scripts = final.callPackage ../pkgs/scripts {};
    airconnect = final.callPackage ../pkgs/airconnect {};
    steam-cage = final.callPackage ../nix/packages/steam-cage {};
    steam-prefs = final.callPackage ../nix/packages/steam-prefs {};
  })
]
