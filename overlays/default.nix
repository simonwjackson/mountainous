[
  (final: prev: {
    vpn-ns = final.callPackage ../packages/vpn-ns {};
    gogcli = final.callPackage ../packages/gogcli {};
    lifted-scripts = final.callPackage ../packages/scripts {};
    airconnect = final.callPackage ../packages/airconnect {};
    steam-cage = final.callPackage ../packages/steam-cage {};
    steam-prefs = final.callPackage ../packages/steam-prefs {};
  })
]
