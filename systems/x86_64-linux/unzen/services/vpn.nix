{
  age,
  config,
  pkgs,
  ...
}: {
  virtualisation.oci-containers.containers = {
    gluetun = {
      autoStart = true;
      image = "qmcgaw/gluetun";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        "--device=/dev/net/tun:/dev/net/tun"
      ];
      environmentFiles = [
        config.age.secrets.gluetun_env.path
      ];
      environment = {
        VPN_SERVICE_PROVIDER = "protonvpn";
      };
    };
  };
}
