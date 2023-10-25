# Exposes a port through SSH
# xpo [local port] [remote host] [remote port]
{
  lib,
  writeShellApplication,
  openssh,
  iptables,
}:
(writeShellApplication {
  name = "xpo";
  runtimeInputs = [openssh iptables];
  text = builtins.readFile ./xpo.sh;
})
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}
