{
  config,
  host,
  ...
}: {
  device = {
    id = "DIVKBPA-VNVTEK5-FH7C2SB-QCSK6ZC-N4OE7AQ-3JX63AR-BDR6WMP-JQZ3KAK";
    name = "Desktop (${host})";
  };
  shares = {
    scripts = {
      path = "/home/simonwjackson/.local/scripts";
      versioning = {
        type = "simple";
        params = {
          keep = "5";
        };
      };
      type = "sendreceive";
      copyOwnershipFromParent = true;
    };
    notes = {
      path = "/snowscape/notes";
      type = "sendreceive";
    };
    gaming-profiles = {
      path = "/snowscape/gaming/profiles";
      type = "sendreceive";
    };
    games = {
      path = "/snowscape/gaming/games";
      type = "sendreceive";
    };
  };
}
