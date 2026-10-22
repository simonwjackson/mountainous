# Pure placement-to-mount contract, consumed by real hosts and VM fixtures.
{
  lib,
  host,
  placement,
  libraryHost,
  libraryServer,
  tailDomain,
  mediaGid,
  libraryOwnerUid,
  libraryMediaGid,
  libraryUsers,
  libraryConsumer ? null,
  # Set when the library lives on this host (the Towada pool on Unzen). The
  # views then read the local path and no NFS mount to the server exists.
  libraryLocalRoot ? null,
}:
let
  local = name: placement.${name} == host;
  hasLibraryConsumer =
    if libraryConsumer != null then
      libraryConsumer
    else
      lib.any local [
        "sonarr"
        "radarr"
      ];
  isLibraryHost = libraryHost == host;
  hasLibraryAccess = hasLibraryConsumer || isLibraryHost;
  downloaders = [
    "nzbget"
    "transmission"
  ];
  mediaRoot = "/srv/basin/media";
  accessRoot = "/srv/media-access";
  libraryView = "/srv/media-library-view";
  # The mount point keeps its historical name whatever the server is called.
  libraryRemote = "/net/mountainous/zao/media";
  librarySource = if libraryLocalRoot != null then libraryLocalRoot else libraryRemote;
  completed =
    name: "/srv/basin/downloads/${if name == "nzbget" then "usenet" else "torrents"}/completed";
  share = name: ".downloads/${if name == "nzbget" then "usenet" else "torrents"}";
  fqdn = name: "${name}.${tailDomain}";
  nfsOptions = [
    "rw"
    "nfsvers=4.2"
    "hard"
    "timeo=50"
    "retrans=2"
    "noatime"
    # Every NFS peer is reached over the tailnet. Mount after Tailscale is
    # connected; at shutdown, unmount before tailscaled stops.
    "x-systemd.requires=tailscale-online.target"
  ];
  # These application mounts follow tmpfiles and remote storage. Treating
  # them as early local mounts creates local-fs/sysinit/network cycles.
  bindOptions = [
    "bind"
    "_netdev"
    "noauto"
    "x-systemd.requires=systemd-tmpfiles-setup.service"
  ];
  unionOptions = [
    "allow_other"
    "use_ino"
    "category.create=ff"
    "minfreespace=10G"
    "_netdev"
    "noauto"
    "x-systemd.requires=systemd-tmpfiles-setup.service"
  ];
  exportedLibrary = lib.optionals isLibraryHost [
    "movies"
    "tv"
  ];
in
lib.foldl' lib.recursiveUpdate { } [
  (lib.genAttrs (map (part: "${accessRoot}/${part}") exportedLibrary) (directory: {
    device = "${mediaRoot}/${baseNameOf directory}";
    fsType = "none";
    options = bindOptions;
  }))
  (lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "${accessRoot}/${share name}" {
        device = completed name;
        fsType = "none";
        options = bindOptions;
      }
    ) (lib.filter local downloaders)
  ))
  (lib.listToAttrs (
    map (
      name:
      lib.nameValuePair (completed name) {
        device = "${fqdn placement.${name}}:/${share name}";
        fsType = "nfs";
        options = nfsOptions;
      }
    ) (lib.filter (name: !local name && hasLibraryConsumer) downloaders)
  ))
  (lib.optionalAttrs (hasLibraryConsumer && !isLibraryHost) {
    ${mediaRoot} = {
      device = "${fqdn libraryHost}:/";
      fsType = "nfs";
      options = nfsOptions;
    };
  })
  (lib.optionalAttrs hasLibraryAccess (
    lib.genAttrs
      (map (part: "${libraryView}/${part}") [
        "movies"
        "tv"
      ])
      (
        directory:
        let
          part = baseNameOf directory;
        in
        {
          device = "${librarySource}/${part}";
          fsType = "fuse.bindfs";
          # Translate the view, not stored ownership. Keep permission checks enabled.
          options = [
            "allow_other"
            "default_permissions"
            "force-user=${toString libraryUsers.${part}}"
            "create-for-user=${toString libraryOwnerUid}"
          ]
          ++ lib.optional (
            libraryMediaGid != mediaGid
          ) "map=@${toString libraryMediaGid}/@${toString mediaGid}"
          ++ [
            "chown-deny"
            "chgrp-deny"
            "_netdev"
            "noauto"
            "x-systemd.requires=systemd-tmpfiles-setup.service"
          ];
          depends = [ librarySource ];
        }
      )
  ))
  (lib.optionalAttrs (hasLibraryAccess && libraryLocalRoot == null) {
    ${libraryRemote} = {
      device = "${fqdn libraryServer}:/";
      fsType = "nfs";
      options = nfsOptions;
    };
  })
  (lib.optionalAttrs hasLibraryConsumer {
    "/srv/range/media/movies" = {
      device = "${mediaRoot}/movies:${libraryView}/movies";
      fsType = "fuse.mergerfs";
      options = unionOptions;
      depends = [ "${libraryView}/movies" ] ++ lib.optional (!isLibraryHost) mediaRoot;
    };
    "/srv/range/media/tv" = {
      device = "${mediaRoot}/tv:${libraryView}/tv";
      fsType = "fuse.mergerfs";
      options = unionOptions;
      depends = [ "${libraryView}/tv" ] ++ lib.optional (!isLibraryHost) mediaRoot;
    };
  })
]
