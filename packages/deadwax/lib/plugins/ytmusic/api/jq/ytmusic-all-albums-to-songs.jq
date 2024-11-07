def duration_to_seconds:
  split(":")
  | map(tonumber)
  | .[0] * 60 + .[1]
  | tonumber;

def base:
  .contents
  .singleColumnBrowseResultsRenderer
  .tabs[0]
  .tabRenderer
  .content
  .sectionListRenderer
  .contents[0]
  .musicPlaylistShelfRenderer
  .contents;

def getFlexColumnText($column_type):
  .musicResponsiveListItemRenderer
  .flexColumns[]
  | select(
      .musicResponsiveListItemFlexColumnRenderer
      .text
      .runs[0]
      .navigationEndpoint
      .browseEndpoint
      .browseEndpointContextSupportedConfigs
      .browseEndpointContextMusicConfig
      .pageType == $column_type
   )
  | .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs;

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
      sources: {
        ytmusic: {
          id: .navigationEndpoint.browseEndpoint.browseId
        }
      }
    };

def get_name:
  .musicResponsiveListItemRenderer
  .flexColumns[0]
  .musicResponsiveListItemFlexColumnRenderer
  .text
  .runs[0]
  .text;

def get_duration:
  .musicResponsiveListItemRenderer
  .fixedColumns[0]
  .musicResponsiveListItemFixedColumnRenderer
  .text
  .runs[0]
  .text
  | duration_to_seconds;

def get_thumbnail:
  .musicResponsiveListItemRenderer
  .thumbnail
  .musicThumbnailRenderer
  .thumbnail
  .thumbnails[-1]
  .url;

def get_video_id:
  .musicResponsiveListItemRenderer
  .playlistItemData
  .videoId;

def get_album_data:
  getFlexColumnText("MUSIC_PAGE_TYPE_ALBUM")[0]
  | {
      name: .text,
      id:
        .navigationEndpoint
        .browseEndpoint
        .browseId
    };

if type != "array" then [.] else . end
| to_entries
| map({
    name: .value | get_name,
    duration: .value | get_duration,
    thumbnail: .value | get_thumbnail,
    sources: {
      youtube: {
        id: .value | get_video_id
      }
    },
    album: (
      (.value | get_album_data) + {
        artists: [
          .value
          | getFlexColumnText("MUSIC_PAGE_TYPE_ARTIST")[]
          | extract_artist_data
        ]
      }
    )
  })
| .[]
