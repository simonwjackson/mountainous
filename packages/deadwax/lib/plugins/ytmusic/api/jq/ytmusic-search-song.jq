# Common helper functions
def get_navigation_endpoint_type($page_type):
  .navigationEndpoint
  .browseEndpoint
  .browseEndpointContextSupportedConfigs
  .browseEndpointContextMusicConfig
  .pageType == $page_type;

def get_music_video_type($video_type):
  .navigationEndpoint
  .watchEndpoint
  .watchEndpointMusicSupportedConfigs
  .watchEndpointMusicConfig
  .musicVideoType == $video_type;

def duration_to_seconds:
  split(":")
  | map(tonumber)
  | .[0] * 60 + .[1]
  | tonumber;

# Column data extraction
def get_flex_column_runs:
  .flexColumns[]
  .musicResponsiveListItemFlexColumnRenderer
  .text
  .runs[];

# Album-related functions
def get_album_data($type):
  select(get_navigation_endpoint_type("MUSIC_PAGE_TYPE_ALBUM"))
  | if $type == "name" then
      .text
    elif $type == "id" then
      .navigationEndpoint.browseEndpoint.browseId
    else
      empty
    end;

def get_album_name:
  get_album_data("name");

def get_album_id:
  get_album_data("id");

# Artist-related functions
def extract_artist_data:
  select(
    get_navigation_endpoint_type("MUSIC_PAGE_TYPE_ARTIST")
    and
    .navigationEndpoint.browseEndpoint.browseId != null
  )
  | {
      name: .text,
      sources: {
        ytmusic: {
          id: .navigationEndpoint.browseEndpoint.browseId
        }
      }
    };

# Song-related functions
def extract_song_data($type):
  get_flex_column_runs
  | select(get_music_video_type("MUSIC_VIDEO_TYPE_ATV"))
  | if $type == "name" then
      .text
    elif $type == "id" then
      .navigationEndpoint.watchEndpoint.videoId
    else
      empty
    end;

def extract_duration:
  get_flex_column_runs
  | select(.text | test("^\\d{1,2}:\\d{2}(:\\d{2})?$"))
  | .text
  | duration_to_seconds;

# Path traversal helpers
def get_contents:
  .contents
  .tabbedSearchResultsRenderer
  .tabs[0]
  .tabRenderer
  .content
  .sectionListRenderer
  .contents[0]
  .musicShelfRenderer
  .contents[];

get_contents
| .musicResponsiveListItemRenderer
| {
    type: "song",
    thumbnail: .thumbnail.musicThumbnailRenderer.thumbnail.thumbnails[-1].url,
    duration: extract_duration,
    album: {
      name: (get_flex_column_runs | get_album_name),
      sources: {
        ytmusic: {
          id: (get_flex_column_runs | get_album_id)
        }
      },
      artists: [
        get_flex_column_runs
        | extract_artist_data
      ],
    },
    name: extract_song_data("name"),
    sources: {
      youtube: {
        id: extract_song_data("id")
      }
    }
  }
