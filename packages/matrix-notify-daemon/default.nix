{
  lib,
  pkgs,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "matrix-notify-daemon";
  runtimeInputs = [
    (pkgs.python3.withPackages (ps: [
      ps.matrix-nio
      ps.dbus-next
    ]))
    pkgs.xdg-utils
  ];
  text = ''
    exec python3 ${./matrix_notify_daemon.py} "$@"
  '';
}
// {
  meta = with lib; {
    description = "Matrix room to desktop notification bridge with bidirectional dismiss sync";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
