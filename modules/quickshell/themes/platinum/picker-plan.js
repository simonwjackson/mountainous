// Existing Platinum sizes: a 28px hit row, 30px tabs, and a thumbnail
// (112px) with its complete two-line label. Never budget decoration before
// a labelled choice. Below the list budget the whole body, Close included,
// scrolls instead of subtracting another fixed row from the viewport.
var thumbnailWidth = 180;
var toolbarHeight = 28;
var tabHeight = 30;
var galleryMinWidth = 220;
var galleryMinHeight = 300;
// Includes the well's insets: the visible 100px fits the longest current
// compact label even with the check column retained. Engine tests measure it.
var minimumListViewport = 112;
var optionRowMinWidth = 140;

function plan(width, height) {
    var padding = Math.max(0, Math.min(12, Math.floor(Math.min(width, height) / 30)));
    var panelWidth = Math.max(1, Math.min(620, width - 2 * padding));
    var panelHeight = Math.max(1, Math.min(360, height - 2 * padding));
    var gap = Math.min(8, padding);
    var thumbnails = width >= galleryMinWidth && height >= galleryMinHeight;
    var closeInBody = width < optionRowMinWidth
        || panelHeight - 2 * padding < toolbarHeight + gap + minimumListViewport;
    return {width: panelWidth, height: panelHeight, padding: padding, gap: gap,
        thumbnails: thumbnails, closeInBody: closeInBody, stackedOption: width < optionRowMinWidth,
        headerHeight: closeInBody ? 0 : toolbarHeight,
        tabsHeight: thumbnails ? tabHeight : 0,
        showNote: thumbnails && height >= 360};
}
