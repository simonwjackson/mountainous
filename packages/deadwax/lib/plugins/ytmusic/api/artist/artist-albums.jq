def first_run_text:
  .runs[0]
  .text;

def content_path:
  .contents
  .singleColumnBrowseResultsRenderer
  .tabs[0]
  .tabRenderer
  .content
  .sectionListRenderer;

def largest_square_thumbnail:
  map(select(.width == .height))
  | sort_by(.width)
  | last
  | .url;

def extract_year:
  select(
    .text
    | test("^\\d{4}$")
  )
  | .text;

def artist_name:
  .header
  .musicHeaderRenderer
  .title
  | first_run_text;

. as $root
| content_path
  .contents[0]
  .gridRenderer
  .items[]
| .musicTwoRowItemRenderer
| {
  type: "album",
  name: .title
         | first_run_text,
  id: .title
      .runs[0]
      .navigationEndpoint
      .browseEndpoint
      .browseId,
  thumbnail: (
    .thumbnailRenderer
    .musicThumbnailRenderer
    .thumbnail
    .thumbnails
    | largest_square_thumbnail
  ),
  year: .subtitle.runs[]
        | extract_year
        | tonumber,
  artists: [{
    name: $root
          | artist_name,
    id: $artistId
  }]
}
