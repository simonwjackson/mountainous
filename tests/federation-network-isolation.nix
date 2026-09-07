# Isolated, standalone check. No Zao imports, deployment commands, or secrets.
{pkgs ? import <nixpkgs> {}}: let
  lib = pkgs.lib;
  source = pkgs.runCommand "federation-network-isolation-source" {} ''
    mkdir "$out"
    cp ${../scripts/federation_network_isolation.py} "$out/federation_network_isolation.py"
    cp ${../scripts/federation_network_isolation.nft} "$out/federation_network_isolation.nft"
  '';
  driver = pkgs.writeText "federation-network-driver.py" (builtins.readFile ./federation-network-driver.py);
  peer = pkgs.writeText "federation-network-peer.py" (builtins.readFile ./federation-network-peer.py);
  collision = pkgs.writeText "network-isolation-collision.nft" ''
    create table inet korri_maintenance_isolation { comment "foreign fixture, never adopt"; }
    add chain inet korri_maintenance_isolation foreign
  '';
  invalid = pkgs.writeText "network-isolation-invalid.nft" ''
    create table inet korri_maintenance_isolation
    add chain inet korri_maintenance_isolation partial
    add rule inet korri_maintenance_isolation nonexistent drop
  '';
  nftAdapter = pkgs.writeShellScript "network-isolation-nft-adapter" ''
    exec ${pkgs.python3}/bin/python3 ${driver} nft-adapter "$@"
  '';
  fixture = pkgs.writeShellScriptBin "network-isolation-fixture" ''
    export NETWORK_MODULE=${source}/federation_network_isolation.py
    export NETWORK_PEER=${peer}
    export NETWORK_NFT=${pkgs.nftables}/bin/nft
    export NETWORK_NFT_ADAPTER=${nftAdapter}
    export NETWORK_COLLISION=${collision}
    export NETWORK_INVALID=${invalid}
    exec ${pkgs.python3}/bin/python3 ${driver} "$@"
  '';
  keys = pkgs.runCommand "network-isolation-fixture-ssh-key" {nativeBuildInputs = [pkgs.openssh];} ''
    mkdir "$out"
    ssh-keygen -q -t ed25519 -N "" -f "$out/key"
  '';
in
  assert lib.versions.major pkgs.systemd.version == "259";
    pkgs.testers.runNixOSTest {
      name = "federation-network-isolation";
      nodes.machine = {config, ...}: {
        virtualisation.memorySize = 1536;
        virtualisation.cores = 2;
        system.stateVersion = "26.05";
        environment.systemPackages = [fixture pkgs.python3 pkgs.openssh pkgs.nftables pkgs.iptables pkgs.iproute2 pkgs.util-linux pkgs.conntrack-tools];
        environment.etc."federation-network-vm-fixture".text = "isolated fixture only\n";
        networking.dhcpcd.denyInterfaces = ["isowire" "tailscale0" "*-peer"];
        networking.firewall = {
          enable = true;
          backend = "iptables";
          trustedInterfaces = ["tailscale0"];
          allowedTCPPorts = [22 443 18080 39217 47984 47989 47990 48010];
          allowedUDPPorts = [53 67 68 546 547 18081 41641 47998 47999 48000 48002 48010 59999 61001];
          allowedUDPPortRanges = [
            {
              from = 60000;
              to = 61000;
            }
          ];
        };
        # Unrelated probes deliberately use ports outside the isolated source-port
        # set. The cutover's explicit sport block also blocks ephemeral overlap.
        boot.kernel.sysctl."net.ipv4.ip_local_port_range" = "32768 39000";
        # Same established sender sockets retain denied TCP bytes across all four
        # actions. Reserve test-only capacity for fresh successful writes.
        boot.kernel.sysctl."net.core.wmem_max" = 4194304;
        boot.kernelModules = ["nf_tables" "nf_conntrack" "veth"];
        services.openssh.enable = true;
        security.pam.services.login.updateWtmp = lib.mkForce false;
        security.pam.services.sshd.updateWtmp = lib.mkForce false;
        users.users.root.openssh.authorizedKeys.keyFiles = ["${keys}/key.pub"];
        environment.etc."network-fixture-key" = {
          source = "${keys}/key";
          mode = "0600";
        };
        users.users.korrid = {
          isSystemUser = true;
          uid = 976;
          group = "korrid";
        };
        users.groups.korrid.gid = 976;
        users.users.operator = {
          isNormalUser = true;
          uid = 1000;
        };
        users.users.unrelated = {
          isNormalUser = true;
          uid = 1001;
        };
        assertions = [
          {
            assertion = !config.networking.nftables.enable;
            message = "exercise the actual pinned iptables firewall, not nftables.service";
          }
        ];
      };
      testScript = ''
        start_all()
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        machine.wait_for_unit("firewall.service")
        with subtest("sender failure and actual nft uncertain-result regressions"):
            failures = []
            for mode in ("sender-reset-checks", "transaction-checks"):
                status, output = machine.execute(f"network-isolation-fixture {mode}", timeout=120)
                print(output)
                if status != 0:
                    failures.append(mode)
            assert not failures, failures
        with subtest("real network and ownership contract matrix"):
            output = machine.succeed("network-isolation-fixture", timeout=600)
            print(output)
        with subtest("nft state survives installer exit, NOT reboot"):
            machine.succeed("nft list table inet korri_maintenance_isolation")
            machine.crash()
            machine.start()
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("sshd.service")
            machine.fail("nft list table inet korri_maintenance_isolation")
            print("PASS: no nft persistence claim; reboot safety requires separate persistent unit gates")
      '';
    }
