Please create a bash script that pipes in a single json object and then calls the appropriate function. create noop function stubs. for this first iteration we are only going to build out the logic for the `songs` command

## Possible combos

```
artists        [--related|--tag]           <songId|albumId|artistId>
artists                                    <songId|albumId|artistId|playlistId>
artists search                             <query>
albums         [--related|--tag]           <songId|albumId|artistId>
albums                                     <songId|albumId|artistId|playlistId>
albums  search                             <query>
songs          [--related|--shuffle|--tag] <albumId|artistId>
songs                                      <songId|albumId|artistId|playlistId>
songs   search                             <query>
search                                     <query>
```
## Piped in json object

```json
{
  type: artists|albums|songs,
  isSearch: boolean,
  payload: songId|albumId|artistId|playlistId|query,
  options: {
    related: boolean,
    shuffle: boolean,
    tag: string
  }
}
```


assuming the command with options is valid:
  call a stubbed function `create_song_list` if the type is songs
  pass in obj as param

## Notes

 * use nix shebang
 * --related, --shuffle & --tag: incompatible with playlist
 * assume `mpreb_to_olak()` exists
 * when an incompatible combo of commands, flags and id types are passed, use `gum log` for warnings and errors
 * a single json object is piped in to the script
 * id is evolved based on logic below
```bash
extract_id() {
  local url="$1"
  local pattern="$2"

  echo "$url" | grep -oP "$pattern"
}

evolve_id() {
  local string=$1
  local id=""

  if [[ "$string" =~ ^https://music\.youtube\.com/channel/UC[a-zA-Z0-9_-]{22}($|\?) ]] || [[ "$string" =~ ^UC[a-zA-Z0-9_-]{22}$ ]]; then
    id=$(extract_id "$string" 'UC[a-zA-Z0-9_-]{22}') || id="$string"
  elif [[ "$string" =~ ^(https://music\.youtube\.com/playlist\?list=)?OLAK5uy_[A-Za-z0-9_-]{33}$ ]]; then
    id=$(extract_id "$string" '(?<=list=)OLAK5uy_[A-Za-z0-9_-]{33}(?=&|$)') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/browse/MPREb_ || "$string" =~ ^MPREb_[a-zA-Z0-9_-]+$ ]]; then
    mpreb_album_id=$(extract_id "$string" 'MPREb_[a-zA-Z0-9_-]+') || id="$string"
    id=$(mpreb_to_olak "$mpreb_album_id")
  elif [[ "$string" =~ ^https://music\.youtube\.com/playlist\?list=RDCLAK5uy_[A-Za-z0-9_-]{33}($|\?) ]] || [[ "$string" =~ ^RDCLAK5uy_[A-Za-z0-9_-]{33}$ ]]; then
    id=$(extract_id "$string" 'RDCLAK5uy_[A-Za-z0-9_-]{33}') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/playlist\?list=PL[A-Za-z0-9_-]{32}($|\?) ]] || [[ "$string" =~ ^PL[A-Za-z0-9_-]{32}$ ]]; then
    id=$(extract_id "$string" 'PL[A-Za-z0-9_-]{32}') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/watch\?v= || "$string" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
    id=$(extract_id "$string" '(?<=v=)[a-zA-Z0-9_-]{11}') || id="$string"
  else
    echo '{ "error": "Invalid id format" }' >&2
    return 1
  fi

  jq -n \
    --arg type "$type" \
    --arg id "$id" '{
      type: $type,
      value: $id,
    }'
}
```


## Calls


### POST: browse

* get albums from artistId
* convert mpreb to olak5
```json
{
    "browseId": "$id"
}
```

### playlist

*

POST: next
```json
{
    "playlistId": "'"$playlistId"'"
}
```


