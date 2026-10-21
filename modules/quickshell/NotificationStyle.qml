pragma Singleton

import Quickshell

// Type and spacing for the notification view. Theme.qml has colour, radius
// and font-family tokens but no type or spacing scale, and the other panels
// write these numbers inline. These are those same numbers, named once, so
// the view reads from one place. They belong in Theme.qml once the shell
// adopts a shared scale.
Singleton {
    // Type, in logical pixels, smallest first.
    readonly property int textHint: 9       // key hints under the list
    readonly property int textDetail: 10    // app name, host, time, tags
    readonly property int textBody: 11      // body text and button labels
    readonly property int textTitle: 12     // a notification's summary
    readonly property int textHeading: 14   // the centre's title
    readonly property int textGlyph: 15     // the × on a card
    readonly property int textGlyphLarge: 16 // the centre's close ×

    // Space, in logical pixels.
    readonly property int gap: 6            // between siblings in a row or column
    readonly property int gapTight: 3       // summary to body
    readonly property int gapWide: 10       // text to its image
    readonly property int gapSection: 8     // between the centre's sections
}
