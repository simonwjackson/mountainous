{
  config,
  host,
  ...
}: {
  device = {
    id = "6SDMTLX-5YQ3QIK-5ZJNOQV-IZZK5O2-VC2QYK2-VKEAKY5-G5PZBXK-AV6RXAR";
    name = "Nixos Phone (${host})";
  };
  shares = {
    notes = {
      path = "/home/simonwjackson/notes";
      type = "sendreceive";
    };
  };
}
