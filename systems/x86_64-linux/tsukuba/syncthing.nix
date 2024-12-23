{
  config,
  host,
  ...
}: {
  device = {
    # TODO: Add your syncthing device id here
    id = "0000000-0000000-0000000-0000000-0000000-0000000-0000000-0000000";
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
