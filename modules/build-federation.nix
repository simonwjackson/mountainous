# The build federation: every machine that may build for the others declares
# itself once, and every other machine sends it work.
#
# A host file adds one entry:
#
#   fleet.builders.unzen = { cpus = 8; speedFactor = 4; hostKey = "ssh-ed25519 ..."; };
#   fleet.hostKeys.unzen = "ssh-ed25519 ...";   # its client identity
#
# From those entries each host gets:
#   - as a client: one `nix.buildMachines` entry per other builder, reached
#     through the ssh alias nix-builder-<name> and signed in with this host's
#     own SSH host key. No key material is shared between machines.
#   - as a builder: every fleet host key may run `nix-builder-gate serve`
#     and nothing else. The gate decides whether to accept (see
#     nix-builder-gate.py), then runs `nix daemon --stdio`. Builds run at idle
#     CPU and IO priority, with a lower MemoryMax than a machine that only
#     builds for itself.
#
# Nix itself picks the builder for each derivation: the one with the lowest
# running jobs / speedFactor that fits the system and features, local build
# when every builder is full, and the next builder when one refuses. See
# docs/decisions/build-federation.md.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  fleet = config.fleet;

  # Zao's remote-build key from before the federation. Zao still runs
  # `unified`, where root signs in with it; drop it when Zao moves to cairn.
  zaoLegacyKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAW4YRgdrxZjOPks6Jy8q4txJ4LZTVUFhNadApat21AG root@zao for remote builders";

  # The NixOS side, as a function of the registry so a test can supply its own.
  federation =
    fleet:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      name = config.networking.hostName;
      cfg = config.mountainous.federation;
      me = fleet.builders.${name} or null;
      serving = me != null && me.managed;
      others = lib.filterAttrs (n: _: n != name) fleet.builders;
      hostKeyPath =
        (lib.findFirst (k: k.type == "ed25519") {
          path = "/etc/ssh/ssh_host_ed25519_key";
        } config.services.openssh.hostKeys).path;

      gate = pkgs.writeShellScriptBin "nix-builder-gate" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.iproute2
            pkgs.coreutils
          ]
        }:/run/wrappers/bin:${lib.makeBinPath [ pkgs.iputils ]}
        export NIX_BUILDER_GATE_DAEMON=${config.nix.package}/bin/nix
        exec ${pkgs.python3}/bin/python3 ${./nix-builder-gate.py} "$@"
      '';
      clientKeys = lib.attrValues (lib.filterAttrs (n: _: n != name) fleet.hostKeys) ++ [ zaoLegacyKey ];
    in
    {
      options.mountainous.federation = {
        client = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Send builds to the fleet's builders.";
        };
        gate = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = gate;
          description = "The nix-builder-gate command, for tests and the bar.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.client && others != { }) {
          nix.distributedBuilds = true;
          nix.buildMachines = lib.mapAttrsToList (n: b: {
            hostName = "nix-builder-${n}";
            protocol = "ssh-ng";
            inherit (b) sshUser maxJobs speedFactor;
            sshKey = hostKeyPath;
            systems = [ b.system ];
            supportedFeatures = b.features;
          }) others;
          # A builder fetches dependencies from the caches itself instead of
          # receiving every one of them over this host's uplink.
          nix.settings.builders-use-substitutes = true;
          # nix-daemon runs ssh as root and reads this file. The alias pins
          # the port and the expected host key; a builder that is down or
          # refuses fails within seconds, and Nix moves on.
          programs.ssh.extraConfig = lib.concatStrings (
            lib.mapAttrsToList (n: b: ''
              Host nix-builder-${n}
                HostName ${n}
                Port ${toString b.sshPort}
                HostKeyAlias nix-builder-${n}
                ConnectTimeout 5
                BatchMode yes
                ServerAliveInterval 30
            '') others
          );
          programs.ssh.knownHosts = lib.mapAttrs' (
            n: b: lib.nameValuePair "nix-builder-${n}" { publicKey = b.hostKey; }
          ) others;
        })

        (lib.mkIf serving {
          users.users.${me.sshUser}.openssh.authorizedKeys.keys = map (
            key: ''restrict,command="${gate}/bin/nix-builder-gate serve" ${key}''
          ) clientKeys;

          nix.settings.max-jobs = me.maxJobs;
          nix.settings.cores = lib.min 4 me.cpus;
          # The machine's own work comes first; builds take what is left.
          nix.daemonCPUSchedPolicy = "idle";
          nix.daemonIOSchedClass = "idle";
          mountainous.memoryGuard.nixDaemon = {
            memoryHigh = me.memoryHigh;
            memoryMax = me.memoryMax;
          };

          services.openssh.ports = lib.mkIf (me.sshPort != 22) [
            22
            me.sshPort
          ];
          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ me.sshPort ];

          environment.systemPackages = [ gate ];
          environment.etc."nix-builder-gate.json".text = builtins.toJSON {
            mode = me.gate;
            homeMacs = fleet.homeMacs;
          };
          systemd.tmpfiles.rules = [
            "d /var/lib/nix-builder-gate 0755 ${me.sshUser} users -"
            "d /run/nix-builder-gate 0755 ${me.sshUser} users -"
            "d /run/nix-builder-gate/sessions 0755 ${me.sshUser} users -"
          ];
        })

        # A home gate learns about a new network at once, not only at the
        # next build: a choice made on another router is cleared here.
        (lib.mkIf (serving && me.gate == "home") {
          networking.networkmanager.dispatcherScripts = [
            {
              type = "basic";
              source = pkgs.writeShellScript "nix-builder-gate-network" ''
                ${pkgs.util-linux}/bin/runuser -u ${me.sshUser} -- ${gate}/bin/nix-builder-gate refresh || true
              '';
            }
          ];
        })
      ];
    };

  builderType = types.submodule (
    { config, ... }:
    {
      options = {
        system = mkOption {
          type = types.str;
          default = "x86_64-linux";
        };
        cpus = mkOption {
          type = types.ints.positive;
          description = "Hardware threads. Jobs and cores per job are derived from it.";
        };
        maxJobs = mkOption {
          type = types.ints.positive;
          default = lib.max 1 (config.cpus / 4);
          description = "Builds at once; each uses up to four cores.";
        };
        speedFactor = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "Higher is preferred. Nix sends work to the lowest jobs / speedFactor.";
        };
        features = mkOption {
          type = types.listOf types.str;
          default = [
            "big-parallel"
            "benchmark"
          ];
          description = "Add kvm and nixos-test only where /dev/kvm exists.";
        };
        sshUser = mkOption {
          type = types.str;
          default = "simon";
        };
        sshPort = mkOption {
          type = types.port;
          default = 22;
          description = "Myoko uses 2222: Tailscale SSH answers on 22 there and ignores forced commands.";
        };
        hostKey = mkOption {
          type = types.str;
          description = "The ed25519 key the builder's OpenSSH presents on sshPort.";
        };
        gate = mkOption {
          type = types.enum [
            "always"
            "home"
          ];
          default = "always";
          description = "home: accept only at home on mains power, unless the owner chooses otherwise.";
        };
        memoryHigh = mkOption {
          type = types.str;
          default = "60%";
        };
        memoryMax = mkOption {
          type = types.str;
          default = "70%";
        };
        managed = mkOption {
          type = types.bool;
          default = true;
          description = "Configured by this flake. False for Zao and Aka, which still run `unified`.";
        };
      };
    }
  );
in
{
  options.fleet = {
    builders = mkOption {
      type = types.attrsOf builderType;
      default = { };
      description = "Machines that build for the rest of the fleet.";
    };
    hostKeys = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Each machine's ed25519 SSH host key: its identity as a build client.";
    };
    homeMacs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "MAC addresses of the home router(s). A `home` gate accepts only behind one of them.";
    };
  };

  config = {
    # Zao and Aka run `unified`. They are listed here so cairn hosts can use
    # them; `unified` keeps a copy of this registry (features/nix-builders).
    fleet.builders.zao = {
      cpus = 16;
      speedFactor = 3;
      sshUser = "simonwjackson";
      features = [
        "big-parallel"
        "benchmark"
        "kvm"
        "nixos-test"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICuVfNwnDbfncfJn0rmxnpbuI4AuwwTINc864esSjmqv";
      managed = false;
    };
    fleet.builders.aka = {
      cpus = 12;
      speedFactor = 4;
      sshUser = "simonwjackson";
      features = [
        "big-parallel"
        "benchmark"
        "kvm"
        "nixos-test"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII39/0ibgjRrTpAHgDu2oBDUPwEC/7mBwey3Km7ZNR5z";
      # Room for a game and the local model before builds.
      memoryHigh = "50%";
      memoryMax = "60%";
      managed = false;
    };
    fleet.hostKeys = {
      zao = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICuVfNwnDbfncfJn0rmxnpbuI4AuwwTINc864esSjmqv";
      aka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII39/0ibgjRrTpAHgDu2oBDUPwEC/7mBwey3Km7ZNR5z";
    };
    fleet.homeMacs = [ "14:21:03:fe:01:37" ];

    # One registry for `unified` to copy: nix eval --json .#fleet
    flake.fleet = {
      builders = lib.mapAttrs (_: b: b) fleet.builders;
      inherit (fleet) hostKeys homeMacs;
      legacyClientKeys = [ zaoLegacyKey ];
    };

    nixos.modules.base = federation fleet;

    # Korri devices lock distributed builds off, and hosts that never build
    # need no builders.
    nixos.modules.korri = {
      mountainous.federation.client = false;
    };
    nixos.modules.no-builds = {
      mountainous.federation.client = false;
    };

    perSystem =
      { pkgs, lib, ... }:
      {
        checks.build-federation-vm = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
          import ../tests/build-federation-vm.nix {
            inherit pkgs federation;
            memoryGuard = config.flake.lib.memoryGuardModule;
          }
        );
        # The registry itself: a malformed router MAC makes a home gate refuse
        # everywhere, and a builder without a host key cannot be reached.
        checks.build-federation-registry =
          let
            isMac = m: builtins.match "([0-9a-f]{2}:){5}[0-9a-f]{2}" m != null;
            homeGates = lib.filterAttrs (_: b: b.gate == "home") fleet.builders;
            problems =
              lib.optional (
                homeGates != { } && (fleet.homeMacs == [ ] || !lib.all isMac fleet.homeMacs)
              ) "fleet.homeMacs must be lower-case MAC addresses"
              ++ lib.concatLists (
                lib.mapAttrsToList (
                  n: b:
                  lib.optional (!lib.hasPrefix "ssh-ed25519 " b.hostKey) "${n}: hostKey is not an ed25519 key"
                  ++ lib.optional (
                    b.managed && !(fleet.hostKeys ? ${n})
                  ) "${n}: a builder must also be listed in fleet.hostKeys"
                ) fleet.builders
              );
          in
          if problems == [ ] then
            pkgs.runCommand "build-federation-registry" { } "touch $out"
          else
            throw "build federation registry:\n  ${lib.concatStringsSep "\n  " problems}";
        checks.nix-builder-gate =
          pkgs.runCommand "nix-builder-gate"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              python3 ${../tests/test_nix_builder_gate.py} ${./nix-builder-gate.py}
              touch $out
            '';
      };
  };
}
