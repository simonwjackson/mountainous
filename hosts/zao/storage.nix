{
  config,
  lib,
  ...
}: let
  lake = "srv-lakes-towada.mount";
  ready = "media-storage-ready.service";
  rangeMounts = ["srv-range-media-tv.mount" "srv-range-media-movies.mount"];
  consumers = [
    "nfs-server"
    "jellyfin"
    "jellyfin-seed-bootstrap"
    "mountainous-media-normalize-permissions"
    "media-tiering-peer-mount"
    "media-tiering-movies-mount"
    "media-tiering-tv-mount"
  ];
in {
  # The actual mount units, not only their helper services, must be gated.
  # Otherwise RequiresMountsFor from a consumer can bypass the helper.
  systemd.units = lib.genAttrs rangeMounts (_: {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      Requires=${lake} ${ready}
      After=${lake} ${ready}
      BindsTo=${lake} ${ready}
    '';
  });
  systemd.services = lib.genAttrs consumers (name: {
    requires = [lake ready] ++ lib.optionals (name == "jellyfin") rangeMounts;
    after = [lake ready] ++ lib.optionals (name == "jellyfin") rangeMounts;
    bindsTo = [lake ready] ++ lib.optionals (name == "jellyfin") rangeMounts;
  });
  # Direct range pulls must not hold local-fs.target while admission waits for
  # an absent USB enclosure. No storage consumer is a required boot target.
  fileSystems.${config.mountainous.features.media.rangeTvDir}.options = ["nofail"];
  fileSystems.${config.mountainous.features.media.rangeMoviesDir}.options = ["nofail"];
}
