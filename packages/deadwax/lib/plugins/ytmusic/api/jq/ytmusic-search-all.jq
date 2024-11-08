def get_thumbnail:
  .thumbnail
  .musicThumbnailRenderer
  .thumbnail
  .thumbnails
  | max_by(.width)
  .url;

def extract_artists:
  [
    .flexColumns[1]
    .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs[]
    | select(
        .navigationEndpoint?
        .browseEndpoint?
        .browseEndpointContextSupportedConfigs?
        .browseEndpointContextMusicConfig?
        .pageType == "MUSIC_PAGE_TYPE_ARTIST"
      )
    | {
        name: .text,
        id:
          .navigationEndpoint
          .browseEndpoint
          .browseId
      }
  ]
  | unique;

def parse_duration:
  (
    # Try to get _length_seconds directly if available
    (.flexColumns[1]
    .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs[]
    | select(._length_seconds != null)
    ._length_seconds)
    //
    # Otherwise, parse from MM:SS format
    (
      .flexColumns[1]
      .musicResponsiveListItemFlexColumnRenderer
      .text
      .runs[]
      | select(.text | strings and test("^[0-9]+:[0-9]+$"))
      | .text
      | split(":")
      | map(tonumber)
      | .[0] * 60 + .[1]
    )
    // null
  );

def parse_playlist($item):
  $item
  | {
      type: "playlist",
      sources: {
        ytmusic: {
          id: .navigationEndpoint.browseEndpoint.browseId
        }
      },
      name: .flexColumns[0].musicResponsiveListItemFlexColumnRenderer.text.runs[0].text
    };

def parse_artist($item):
  $item
  | {
      type: "artist",
      name: .flexColumns[0].musicResponsiveListItemFlexColumnRenderer.text.runs[0].text,
      sources: {
        ytmusic: {
          id: .navigationEndpoint.browseEndpoint.browseId
        }
      }
    };

def parse_album($item):
  $item
  | {
      type: "album",
      sources: {
        ytmusic: {
          id: .navigationEndpoint.browseEndpoint.browseId
        }
      },
      name: .flexColumns[0].musicResponsiveListItemFlexColumnRenderer.text.runs[0].text,
      year: ((.flexColumns[1].musicResponsiveListItemFlexColumnRenderer.text.runs[]
        | select(.text | test("^[0-9]{4}$")).text) // null),
      thumbnail: {
        url: get_thumbnail
      },
      artists: extract_artists
    };

def parse_song($item):
  $item
  | {
      type: "song",
      title:
        .flexColumns[0]
        .musicResponsiveListItemFlexColumnRenderer
        .text
        .runs[0]
        .text,
      album: {
        name: (
          .flexColumns[1]
          .musicResponsiveListItemFlexColumnRenderer
          .text
          .runs[]
          | select(
              .navigationEndpoint?
              .browseEndpoint?
              .browseEndpointContextSupportedConfigs?
              .browseEndpointContextMusicConfig?
              .pageType == "MUSIC_PAGE_TYPE_ALBUM"
            )
          .text
        ),
        id: (
          .flexColumns[1]
          .musicResponsiveListItemFlexColumnRenderer
          .text
          .runs[]
          | select(
              .navigationEndpoint?
              .browseEndpoint?
              .browseEndpointContextSupportedConfigs?
              .browseEndpointContextMusicConfig?
              .pageType == "MUSIC_PAGE_TYPE_ALBUM"
            )
          .navigationEndpoint
          .browseEndpoint
          .browseId
        ),
        artists: extract_artists
      },
      duration: parse_duration,
      thumbnail: {
        url: get_thumbnail
      },
      sources: {
        ytmusic: {
          id: .playlistItemData.videoId
        }
      }
    };

# Main processing logic
.contents
.tabbedSearchResultsRenderer
.tabs[0]
.tabRenderer
.content
.sectionListRenderer
.contents[]
| select(.musicShelfRenderer != null)
| .musicShelfRenderer
| {
    type: .title.runs[0].text,
    items: .contents[].musicResponsiveListItemRenderer
  }
| if .type == "Featured playlists" or .type == "Community playlists" then
    .items | parse_playlist(.)
  elif .type == "Artists" then
    .items | parse_artist(.)
  elif .type == "Albums" then
    .items | parse_album(.)
  elif .type == "Songs" then
    .items | parse_song(.)
  else
    empty
  end

