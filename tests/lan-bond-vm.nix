# A host with two LAN ports (eth1, eth2) bonded active-backup through
# NetworkManager, and a router serving DHCP on that LAN. Proves one address,
# the primary port active, failover when it loses link, and failback.
{ pkgs, bondModule }:
pkgs.testers.runNixOSTest {
  name = "lan-bond";
  nodes.router = {
    virtualisation.vlans = [ 1 ];
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = "192.168.77.1";
        prefixLength = 24;
      }
    ];
    networking.firewall.enable = false;
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = "eth1";
        dhcp-range = "192.168.77.100,192.168.77.150,1h";
      };
    };
  };
  nodes.host =
    { lib, ... }:
    {
      imports = [ bondModule ];
      virtualisation.vlans = [
        1
        1
      ];
      networking.useDHCP = false;
      networking.interfaces = lib.mkForce { };
      networking.networkmanager.enable = true;
      networking.firewall.enable = false;
      mountainous.features.lan-bond = {
        enable = true;
        primary = "eth2";
        backup = "eth1";
      };
    };
  testScript = ''
    import re

    router.wait_for_unit("dnsmasq.service")
    host.wait_for_unit("NetworkManager.service")

    def active() -> str:
        text = host.succeed("cat /proc/net/bonding/bond0")
        match = re.search(r"Currently Active Slave: (\S+)", text)
        assert match is not None, text
        return match.group(1)

    with subtest("one bond address from DHCP, primary port active"):
        host.wait_until_succeeds("ip -4 -br addr show bond0 | grep -q 192.168.77.", timeout=90)
        for port in ["eth1", "eth2"]:
            assert host.execute(f"ip -4 -br addr show {port} | grep -q 192.168.77.")[0] != 0, port
        text = host.succeed("cat /proc/net/bonding/bond0")
        assert "fault-tolerance (active-backup)" in text, text
        assert "Primary Slave: eth2" in text, text
        assert active() == "eth2"
        host.succeed("ping -c 2 -W 2 192.168.77.1")
        # Each bonded port is held by its bond profile, never an automatic one.
        active_profiles = dict(
            line.rsplit(":", 1)[::-1]
            for line in host.succeed("nmcli -t -f NAME,DEVICE connection show --active").split()
            if ":" in line
        )
        assert active_profiles.get("eth1") == "bond0-eth1", active_profiles
        assert active_profiles.get("eth2") == "bond0-eth2", active_profiles

    with subtest("primary loses link: backup takes over and traffic continues"):
        host.succeed("ip link set eth2 down")
        host.wait_until_succeeds("grep -q 'Currently Active Slave: eth1' /proc/net/bonding/bond0", timeout=10)
        host.succeed("ping -c 2 -W 2 192.168.77.1")

    with subtest("primary returns: traffic moves back to it"):
        host.succeed("ip link set eth2 up")
        host.wait_until_succeeds("grep -q 'Currently Active Slave: eth2' /proc/net/bonding/bond0", timeout=15)
        host.succeed("ping -c 2 -W 2 192.168.77.1")
  '';
}
