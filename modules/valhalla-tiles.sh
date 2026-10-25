# Build a Valhalla tile extract from an OpenStreetMap extract and swap it in.
#
# Inputs (environment):
#   VALHALLA_DATA           directory that holds the live extract; one filesystem
#   VALHALLA_PBF_URL        the .osm.pbf to build from; "$URL.md5" must exist
#   VALHALLA_CONCURRENCY    mjolnir worker threads; the build's memory scales with it
#   VALHALLA_SMOKE_REQUEST  a /route request the new extract must answer
#
# The live extract is "$VALHALLA_DATA/valhalla_tiles.tar". It changes only by a
# rename on the same filesystem, after the new extract has answered the smoke
# route, so the server never sees a partial file. The extract it replaces stays
# as valhalla_tiles.previous.tar, for rollback. A failed run leaves both alone.

: "${VALHALLA_DATA:?}" "${VALHALLA_PBF_URL:?}" "${VALHALLA_CONCURRENCY:?}" "${VALHALLA_SMOKE_REQUEST:?}"

data=$VALHALLA_DATA
work=$data/work
live=$data/valhalla_tiles.tar
previous=$data/valhalla_tiles.previous.tar
pbf=$work/extract.osm.pbf

# A run that died part way leaves its work directory; start clean.
rm -rf "$work"
mkdir -p "$work"

echo "downloading $VALHALLA_PBF_URL"
fetch() {
  curl --fail --location --silent --show-error \
    --retry 5 --retry-delay 60 --retry-all-errors \
    --output "$2" "$1"
}
fetch "$VALHALLA_PBF_URL" "$pbf"
fetch "$VALHALLA_PBF_URL.md5" "$pbf.md5"
expected=$(cut -d ' ' -f 1 <"$pbf.md5")
actual=$(md5sum "$pbf" | cut -d ' ' -f 1)
if [ "$expected" != "$actual" ]; then
  echo "checksum mismatch: expected $expected, got $actual" >&2
  exit 1
fi

# Every path the build writes stays in the work directory, on the data disk.
# Elevation, transit, traffic and landmarks are not built.
valhalla_build_config \
  --mjolnir-tile-dir "$work/tiles" \
  --mjolnir-tile-extract "$work/valhalla_tiles.tar" \
  --mjolnir-admin "$work/admins.sqlite" \
  --mjolnir-timezone "$work/timezones.sqlite" \
  --mjolnir-traffic-extract "$work/traffic.tar" \
  --mjolnir-landmarks "$work/landmarks.sqlite" \
  --mjolnir-transit-dir "$work/transit" \
  --additional-data-elevation "$work/elevation/" \
  --mjolnir-concurrency "$VALHALLA_CONCURRENCY" |
  jq '.mjolnir.logging.color = false | .logging.color = false' >"$work/build.json"

echo "building admin areas"
valhalla_build_admins --config "$work/build.json" "$pbf"
echo "building tiles with $VALHALLA_CONCURRENCY threads"
valhalla_build_tiles --config "$work/build.json" "$pbf"
echo "writing the tile extract"
valhalla_build_extract --config "$work/build.json" --overwrite

# The new extract must route before it goes live.
valhalla_service "$work/build.json" route "$VALHALLA_SMOKE_REQUEST" >"$work/smoke.json"
if ! jq -e '.trip.status == 0' "$work/smoke.json" >/dev/null; then
  echo "the new extract did not answer the smoke route:" >&2
  head -c 2000 "$work/smoke.json" >&2
  exit 1
fi

if [ -e "$live" ]; then
  ln -f "$live" "$previous"
fi
mv -f "$work/valhalla_tiles.tar" "$live"
rm -rf "$work"
echo "valhalla extract swapped in: $(stat -c %s "$live") bytes"
