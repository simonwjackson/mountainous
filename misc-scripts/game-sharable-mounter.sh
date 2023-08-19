cat /tank/gaming/devices/haku/platforms | xargs -I % sudo mkdir -p /run/gaming-shares/haku/mounts/games/%
cat /tank/gaming/devices/haku/platforms | xargs -I % sudo mount --bind /tank/gaming/games/% /run/gaming-shares/haku/mounts/games/%

sudo mkdir -p /run/gaming-shares/haku/share
mountpoint -q /run/gaming-shares/haku/share \
  || sudo mount --bind /tank/gaming /run/gaming-shares/haku/share

mountpoint -q /run/gaming-shares/haku/share \
  || sudo mount --bind /tank/gaming /run/gaming-shares/haku/share

mountpoint -q /run/gaming-shares/haku/share/games \
  || sudo mount --rbind /run/gaming-shares/haku/mounts/games /run/gaming-shares/haku/share/games
