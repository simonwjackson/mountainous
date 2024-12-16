{
  config,
  host,
  ...
}: {
  device = {
    id = "ABVHUQR-BIPNGCS-W7RGGEV-HBA3R4C-UWQAYWQ-KCBPJ6D-PIPLQYU-CXHOWAD";
    name = "Laptop (${host})";
  };
  shares = {
    notes = {
      path = "/glacier/snowscape/notes";
      type = "sendreceive";
    };
  };
}
