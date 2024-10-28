def extract_artist($run):
  select(
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

.contents
.tabbedSearchResultsRenderer
.tabs[0]
.tabRenderer
.content.sectionListRenderer
.contents[0]
.musicShelfRenderer.contents[] |
.musicResponsiveListItemRenderer as $item |
{
  type: "album",
  thumbnail: (
    $item
    .thumbnail
    .musicThumbnailRenderer
    .thumbnail
    .thumbnails
    | max_by(.width)
    | .url
  ),
  artists: (
    $item
    .flexColumns[1]
    .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs
    | map(select(
        .navigationEndpoint?
        .browseEndpoint?
        .browseId?
        | strings
        | test("UC[a-zA-Z0-9_-]{22}")?
      ))
    | map({
        name: .text,
        id: .navigationEndpoint.browseEndpoint.browseId
      })
  ),
  id: (
    $item
    .navigationEndpoint
    .browseEndpoint
    .browseId
  ),
  name: (
    $item
    .flexColumns[0]
    .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs[0]
    .text
  ),
  year: (
    $item
    .flexColumns[1]
    .musicResponsiveListItemFlexColumnRenderer
    .text
    .runs
    | map(select(.text | test("^[0-9]{4}$")))
    | .[0].text
    | tonumber
    // null
  )
}
