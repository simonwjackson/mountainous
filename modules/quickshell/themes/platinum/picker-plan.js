// Decoration yields first; the collection reflows before it scrolls.
var thumbnailWidth = 180;
function plan(width, height) {
    var padding = Math.max(2, Math.min(12, Math.floor(Math.min(width, height) / 30)));
    return {width: Math.max(1, Math.min(620, width - 2 * padding)),
        height: Math.max(1, Math.min(360, height - 2 * padding)), padding: padding,
        gap: Math.max(2, Math.min(8, padding)), showNote: height >= 300};
}
