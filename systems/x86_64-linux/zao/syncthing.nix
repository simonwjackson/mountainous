{
  config,
  host,
  ...
}: {
  device = {
    id = "CTOOG4Z-5WK7MDW-UQ3KHOI-YEMDGQF-D6JSIMG-BNPJZWN-MPN3RTO-TBFKRAN";
    name = "Gaming (${host})";
  };
  shares = {
    scripts = {
      path = "/home/simonwjackson/.local/scripts";
      type = "sendreceive";
    };
    notes = {
      path = "/glacier/snowscape/notes";
      type = "sendreceive";
    };
    gaming-profiles = {
      path = "/glacier/snowscape/gaming/profiles";
      type = "sendreceive";
    };
  };
}
