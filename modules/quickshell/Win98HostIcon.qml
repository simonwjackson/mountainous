import QtQuick
import "themes/win98/host-icon.js" as HostIcon

// A Fleet host: the computer at 16 or 32 u, its shape the host's status
// (up, down, paused, pending) and its overlay the tone (danger, warning;
// muted draws the computer through the 50% checker). selected tints half
// the computer's pixels in the selection colour (Large Icons). See
// themes/win98/host-icon.js.
Win98Svg {
    id: root

    property string hostStatus: "up"
    property string tone: "normal"
    property int size: 16
    property bool selected: false

    width: size * root.u
    height: size * root.u
    svg: HostIcon.svg(root.hostStatus, root.tone, root.size, root.selected, { selection: String(Win98Tokens.selection) })
}
