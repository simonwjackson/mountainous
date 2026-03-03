{ config, lib, pkgs, pyxis, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../profiles/server
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
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ=="
    ];
  };

  # ── Agenix ───────────────────────────────────────────────────────────

  age.identityPaths = lib.mkForce [
    "/tundra/permafrost/etc/ssh/ssh_host_rsa_key"
  ];

  age.secrets."pandora-password" = {
    file = ../../secrets/pandora-password.age;
    owner = "simonwjackson";
    group = "users";
  };

  # ── Pyxis ────────────────────────────────────────────────────────────

  services.pyxis = {
    enable = true;
    package = pyxis.packages.x86_64-linux.default;
    server.port = 8765;
    server.hostname = "kita";
    web.port = 5678;
    web.allowedHosts = [ "pyxis.hummingbird-lake.ts.net" ];
    sources.pandora.username = "simonwjackson@gmail.com";
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

  services.tailscale.enable = true;

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
