{
  config,
  host,
  ...
}: {
  device = {
    id = "J6JEBGV-GDLTLZA-JKIS5PM-EYJ6IS5-QBDM3KP-LSGBR2D-S5VXSYE-TWMVYQ5";
    name = "GPD Win (${host})";
  };
  shares = {
    scripts = {
      path = "/home/simonwjackson/.local/scripts";
      type = "sendreceive";
      versioning = {
        type = "simple";
        params = {
          keep = "5";
        };
      };
    };
    notes = {
      path = "/storage/blizzard/notes";
      type = "sendreceive";
    };
    gaming-profiles = {
      path = "/snowscape/gaming/profiles";
      type = "sendreceive";
    };
    games = {
      path = "/snowscape/gaming/games";
      type = "sendreceive";
      blacklist = [
        "steam/**"
      ];
    };
    code = {
      path = "/storage/blizzard/code";
      type = "sendreceive";
      ignorePerms = false;
    };
    videos = {
      path = "/snowscape/videos";
      whitelist = [];
    };
  };
}
