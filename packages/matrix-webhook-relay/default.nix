{
  lib,
  pkgs,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "matrix-webhook-relay";
  runtimeInputs = [
    (pkgs.python3.withPackages (ps: [
      ps.aiohttp
    ]))
  ];
  text = ''
    exec python3 ${./matrix_webhook_relay.py} "$@"
  '';
}
// {
  meta = with lib; {
    description = "HTTP webhook to Matrix room relay for service notifications";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
