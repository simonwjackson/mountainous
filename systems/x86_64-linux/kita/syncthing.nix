{
  config,
  host,
  ...
}: {
  device = {
    # id = "0000000-0000000-0000000-0000000-0000000-0000000-0000000-0000000";
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
