.contents
.tabbedSearchResultsRenderer
.tabs[0]
.tabRenderer
.content
.sectionListRenderer
.contents[]
| select(.musicShelfRenderer?)
| .musicShelfRenderer
  .contents[]
| .musicResponsiveListItemRenderer
| {
    name: (
      .flexColumns[0]
      .musicResponsiveListItemFlexColumnRenderer
      .text
      .runs[0]
      .text
    ),
    id: (
      .navigationEndpoint
      .browseEndpoint
      .browseId
    ),
    thumbnail:
      .thumbnail
      .musicThumbnailRenderer
      .thumbnail
      .thumbnails[0]
      .url
  }
