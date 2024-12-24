{
  config,
  host,
  ...
}: {
  device = {
    id = "";
    name = "(${host})";
  };
  shares = {
    # TODO: Add your syncthing shares here
    #  shareName= {
    #   path = "/path/to/share";
    #   type = "sendreceive";
    # };
  };
}
