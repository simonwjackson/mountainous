{ config, lib, pkgs, pyxis, gomod2nix, ... }:

let
  buildGoApplication = gomod2nix.legacyPackages.${pkgs.system}.buildGoApplication;
  tsnet-proxy-pkg = buildGoApplication {
    pname = "tsnet-proxy";
    version = "1.0.0";
    src = ../../pkgs/tsnet-proxy;
    modules = ../../pkgs/tsnet-proxy/gomod2nix.toml;
    ldflags = [ "-s" "-w" ];
    doCheck = false;
  };
in

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../profiles/server
    ../../modules/tsnet-proxy
    pyxis.nixosModules.default
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "kita";
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "America/Denver";

  # ── Users ────────────────────────────────────────────────────────────

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };

  # ── Agenix ───────────────────────────────────────────────────────────

  age.identityPaths = lib.mkForce [
    "/tundra/permafrost/etc/ssh/ssh_host_rsa_key"
  ];

  age.secrets."pandora-password" = {
    file = ../../secrets/pandora-password.age;
    mode = "0444";  # DynamicUser can't own files; world-readable for service access
  };

  age.secrets."tailscale-ephemeral" = {
    file = ../../secrets/tailscale-ephemeral.age;
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  # ── Tsnet Proxy ──────────────────────────────────────────────────────

  mountainous.services.tsnet-proxy = {
    enable = true;
    package = tsnet-proxy-pkg;
    authKeyFile = config.age.secrets."tailscale-ephemeral".path;
    services.pyxis = {
      hostname = "pyxis";
      protocol = "http";
      host = "localhost";
      port = 8765;
    };
  };

  # ── Pyxis ────────────────────────────────────────────────────────────

  services.pyxis = {
    enable = true;
    package = pyxis.packages.x86_64-linux.default;
    server.port = 8765;
    server.hostname = "kita";
    server.externalUrl = "http://192.168.1.174:8765";
    web.port = 5678;
    web.allowedHosts = [ "pyxis.hummingbird-lake.ts.net" ];
    sources.pandora.username = "simon@simonwjackson.com";
    sources.pandora.passwordFile = config.age.secrets."pandora-password".path;
    log.level = "info";
  };

  # ── NFS Client (autofs — access aka exports) ────────────────────────

  services.autofs = {
    enable = true;
    autoMaster = let
      nfsOpts = "nfsvers=4,soft,nocto,async,timeo=14,retrans=2";
    in ''
      /net -hosts -${nfsOpts} --timeout=600
    '';
  };

  environment.systemPackages = with pkgs; [ nfs-utils ];

  # ── Tailscale ────────────────────────────────────────────────────────

  # Enabled globally from flake defaults via mountainous.tailscale.

  # ── Ephemeral root (tmpfs) + Impermanence ───────────────────────────

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=2G" "mode=755" ];
  };

  fileSystems."/nix".neededForBoot = true;
  fileSystems."/tundra/permafrost".neededForBoot = true;

  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      {
        directory = "/var/lib/tsnet-proxy-pyxis";
        user = "tsnet-proxy";
        group = "tsnet-proxy";
        mode = "0700";
      }
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/tundra/igloo";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/home/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/tundra/igloo".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/nix/var/nix/profiles/per-user/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
  };

  # ── SSH ──────────────────────────────────────────────────────────────

  services.openssh.hostKeys = [
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # ── Network ──────────────────────────────────────────────────────────

  networking.wireless.enable = lib.mkForce false;
  networking.firewall.enable = lib.mkForce false;

  # ── Power ────────────────────────────────────────────────────────────

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  system.stateVersion = "24.11";
}
