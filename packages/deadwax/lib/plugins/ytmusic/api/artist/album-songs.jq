# Helper function to get to the music queue renderer
def get_queue_path:
  .contents
  .singleColumnMusicWatchNextResultsRenderer
  .tabbedRenderer
  .watchNextTabbedResultsRenderer
  .tabs[0]
  .tabRenderer
  .content
  .musicQueueRenderer;

# Extract album info first
def get_album_info:
  .contents
  .singleColumnMusicWatchNextResultsRenderer
  .tabbedRenderer
  .watchNextTabbedResultsRenderer
  .tabs[0]
  .tabRenderer
  .content
  .musicQueueRenderer
  | {
    album: (
      .header
      .musicQueueHeaderRenderer
      .subtitle
      .runs[0]
      .text
    ),
    albumId: (
      .content
      .playlistPanelRenderer
      .playlistId
    )
  };

# Convert duration string to seconds
def duration_to_seconds:
  split(":")
  | map(tonumber)
  | .[0] * 60 + .[1]
  | tonumber;

# Extract artist information
def get_artists:
  .longBylineText
  .runs[]
  | select(
      .navigationEndpoint?
      .browseEndpoint?
      .browseId?
      | strings
      | test("UC[a-zA-Z0-9_-]{22}")?
    )
  | {
      name: .text,
      id: .navigationEndpoint.browseEndpoint.browseId
    };

# Main query
get_album_info as $album_info |

get_queue_path
.content
.playlistPanelRenderer
.contents
| length as $total
| range(0; $total) as $i
| .[$i]
| select(.playlistPanelVideoRenderer != null)
| .playlistPanelVideoRenderer
| {
  order: ($i + 1),
  title: .title
         .runs[0]
         .text,
  duration: (
    .lengthText
    .runs[0]
    .text
    | duration_to_seconds
  ),
  thumbnail:
    .thumbnail
    .thumbnails[-1]
    .url,
  source: .videoId,
  url: "https://www.youtube.com/watch?v=\(.videoId)",
  album: {
    name: $album_info.album,
    id: $album_info.albumId,
    artists: [get_artists]
  }
} | tojson
