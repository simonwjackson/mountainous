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
      type = "sendreceive";
    };
    # notes = {
    #   path = "/glacier/snowscape/notes";
    #   type = "sendreceive";
    # };
    # gaming-profiles = {
    #   path = "/glacier/snowscape/gaming/profiles";
    #   type = "sendreceive";
    # };
  };
}
