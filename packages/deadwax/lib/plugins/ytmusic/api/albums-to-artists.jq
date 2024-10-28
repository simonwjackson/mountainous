if type != "array" then [.] else . end
| map(
    .artists[] as $artist
    | {
        name: $artist.name,
        id: $artist.id,
        albums: [{
            name: .name,
            year: .year,
            thumbnail: .thumbnail,
            songs: .songs
              | map({
                  title,
                  duration,
                  sources
              })
        }]
    }
)
| group_by(.name)
| map(
    .[0] * {
        albums: map(.albums[])
    }
)
| sort_by(.name)
| .[]
