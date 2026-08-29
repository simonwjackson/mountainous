{
  config,
  lib,
  ...
}: let
  inherit (lib) attrByPath mapAttrs mapAttrsToList mkOption types;

  get = path: default: attrByPath path default config;
  enabled = path: get path false;
  hasSecret = name: builtins.hasAttr name config.age.secrets;
  hasService = name: builtins.hasAttr name config.systemd.services;

  towadaDisks = get ["mountainous" "features" "disk-array" "pools" "towada" "disks"] [];
  towadaDiskIds = map (disk: disk.id) towadaDisks;
  jellyfinLibraries = get ["mountainous" "features" "jellyfin" "bootstrap" "libraries"] {};

  commitments = {
    towada-storage = {
      assertion =
        enabled ["mountainous" "features" "disk-array" "enable"]
        && towadaDiskIds == ["00" "01" "02" "03" "04"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "cache" "enable"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "mergerfs" "dataDisks"] [] == ["00" "01" "04"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "enable"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "dataDisks"] [] == ["00" "01" "04"]
        && get ["mountainous" "features" "disk-array" "pools" "towada" "snapraid" "parityDisks"] [] == ["02" "03"]
        && enabled ["mountainous" "features" "disk-array" "pools" "towada" "usb" "disableAutosuspend"];
      message = "Towada must retain its five-disk mergerfs, cache, and SnapRAID layout.";
    };

    media-tiering-sink = {
      assertion =
        enabled ["mountainous" "features" "media" "enable"]
        && get ["mountainous" "features" "media" "root"] null == "/srv/lakes/towada"
        && enabled ["mountainous" "features" "media-tiering" "enable"]
        && get ["mountainous" "features" "media-tiering" "role"] null == "sink"
        && get ["mountainous" "features" "media-tiering" "peerHost"] null == "yari";
      message = "Zao must remain the Towada media-tiering sink for Yari.";
    };

    jellyfin-media-server = {
      assertion =
        enabled ["mountainous" "features" "jellyfin" "enable"]
        && enabled ["mountainous" "features" "jellyfin" "openFirewall"]
        && enabled ["mountainous" "features" "jellyfin" "bootstrap" "enable"]
        && enabled ["mountainous" "features" "jellyfin" "bootstrap" "remoteAccess"]
        && enabled ["mountainous" "features" "jellyfin" "proxy" "enable"]
        && get ["mountainous" "features" "jellyfin" "proxy" "hostname"] null == "watch"
        && enabled ["services" "jellyfin" "enable"]
        && attrByPath ["tv" "path"] null jellyfinLibraries == "/srv/range/media/tv"
        && attrByPath ["movies" "path"] null jellyfinLibraries == "/srv/range/media/movies"
        && hasSecret "jellyfin-pass";
      message = "Zao must retain Jellyfin with its TV and movie libraries and admin secret.";
    };

    korri-stream-source = {
      assertion =
        enabled ["services" "korri" "daemon" "enable"]
        && enabled ["services" "korri" "daemon" "openFirewall"]
        && builtins.elem "tailscale0" (get ["services" "korri" "daemon" "firewallInterfaces"] [])
        && enabled ["services" "korri" "daemon" "streamControl" "enable"]
        && enabled ["services" "korri" "daemon" "streaming" "enable"]
        && enabled ["services" "korri" "compositor" "enable"]
        && enabled ["services" "sunshine" "enable"]
        && enabled ["services" "sunshine" "openFirewall"];
      message = "Zao must retain the Korri daemon, compositor, stream control, and Sunshine source.";
    };

    korri-runtime = {
      assertion =
        enabled ["programs" "sway" "enable"]
        && enabled ["programs" "sway" "xwayland" "enable"]
        && enabled ["programs" "steam" "enable"]
        && enabled ["programs" "gamemode" "enable"]
        && enabled ["services" "seatd" "enable"]
        && enabled ["services" "pipewire" "enable"]
        && enabled ["services" "pipewire" "wireplumber" "enable"]
        && enabled ["hardware" "graphics" "enable"]
        && enabled ["hardware" "graphics" "enable32Bit"]
        && enabled ["services" "korri" "input" "provider" "enable"]
        && builtins.elem "uinput" config.boot.kernelModules;
      message = "Zao must retain the graphics, audio, input, and gaming runtime required by Korri.";
    };

    shared-office-printer = {
      assertion =
        enabled ["services" "printing" "enable"]
        && enabled ["services" "printing" "openFirewall"]
        && hasService "ensure-office-printer"
        && builtins.elem "multi-user.target" (get ["systemd" "services" "ensure-office-printer" "wantedBy"] [])
        && enabled ["services" "avahi" "enable"]
        && enabled ["services" "avahi" "publish" "userServices"];
      message = "Zao must retain the shared Office Printer queue and Avahi publication.";
    };

    tailnet-access = {
      assertion =
        enabled ["mountainous" "features" "tailscale" "enable"]
        && enabled ["mountainous" "features" "tsnet-proxy" "enable"]
        && hasSecret "tailscale-authkey"
        && builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;
      message = "Zao must retain tsnet-proxy, its Tailscale secret, and trusted tailnet access.";
    };

    eval-memory-safety = {
      assertion =
        enabled ["zramSwap" "enable"]
        && get ["zramSwap" "algorithm"] null == "zstd"
        && get ["zramSwap" "memoryPercent"] null == 50;
      message = "Zao must retain its zstd zram configuration for Nix evaluation memory pressure.";
    };
  };
in {
  options.mountainous.hosts.zao.commitments = mkOption {
    type = types.attrsOf types.bool;
    readOnly = true;
    description = "Named operational commitments that every Zao configuration must preserve.";
  };

  config = {
    mountainous.hosts.zao.commitments = mapAttrs (_: commitment: commitment.assertion) commitments;

    assertions =
      mapAttrsToList (name: commitment: {
        inherit (commitment) assertion;
        message = "Zao commitment '${name}' is not satisfied. ${commitment.message}";
      })
      commitments;
  };
}
