def duration_to_seconds:
  split(":")
  | map(tonumber)
  | .[0] * 60 + .[1]
  | tonumber;

def extract_artist_data:
  select(
    .navigationEndpoint
    .browseEndpoint
    .browseEndpointContextSupportedConfigs
    .browseEndpointContextMusicConfig
    .pageType == "MUSIC_PAGE_TYPE_ARTIST"
     and
    .navigationEndpoint
    .browseEndpoint
    .browseId != null
  )
  | {
      name: .text,
      id: .navigationEndpoint.browseEndpoint.browseId
  };

def get_artists:
  .longBylineText.runs[]
  | extract_artist_data;

def get_album_name($root):
  (
    .longBylineText.runs[]
    | select(
        .navigationEndpoint
        .browseEndpoint
        .browseEndpointContextSupportedConfigs
        .browseEndpointContextMusicConfig
        .pageType == "MUSIC_PAGE_TYPE_ALBUM"
      )
      .text
  ) // (
    $root.contents
    .singleColumnMusicWatchNextResultsRenderer
    .tabbedRenderer
    .watchNextTabbedResultsRenderer
    .tabs[0]
    .tabRenderer
    .content
    .musicQueueRenderer
    .header
    .musicQueueHeaderRenderer
    .subtitle
    .runs[0]
    .text
  );

def get_album_id:
  (
    .longBylineText.runs[]
    | select(
        .navigationEndpoint
        .browseEndpoint
        .browseEndpointContextSupportedConfigs
        .browseEndpointContextMusicConfig
        .pageType == "MUSIC_PAGE_TYPE_ALBUM"
      )
      .navigationEndpoint
      .browseEndpoint
      .browseId
  ) // (
    .navigationEndpoint.watchEndpoint.playlistId // null
  );

def get_album_year:
  if .longBylineText.runs[-1].text | test("^\\d{4}$")
  then
    .longBylineText.runs[-1].text | tonumber
  else
    null
  end;

def get_album_data($root):
  {
    name: get_album_name($root),
    id: get_album_id,
    year: get_album_year,
    artists: [get_artists]
  };

# Need to assign root to a variable first
. as $root
| [.contents
.singleColumnMusicWatchNextResultsRenderer
.tabbedRenderer
.watchNextTabbedResultsRenderer
.tabs[0]
.tabRenderer
.content
.musicQueueRenderer
.content
.playlistPanelRenderer
.contents[]
| select(.playlistPanelVideoRenderer)
| .playlistPanelVideoRenderer]
| to_entries[]
| {
    order: (.key + 1),
    title: .value.title.runs[0].text,
    album: .value | get_album_data($root),
    duration: .value.lengthText.runs[0].text | duration_to_seconds,
    thumbnail: .value.thumbnail.thumbnails[-1].url,
    sources: {
      youtube: {
        id: .value.videoId
      }
    }
  }
