{
  config,
  host,
  ...
}: {
  device = {
    id = "ETEYYE4-C3P2L34-HIV54WA-XQRERGB-LXL5ZRZ-FVA4EXR-YUDRQVL-HV2FDQA";
    name = "Home Server (${host})";
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
  };
}
