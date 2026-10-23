import QtQuick
import QtQuick.Layouts

// The clock's menu: the full date. The bar's clock gives up its date
// first when the bar is narrow; the date stays one click away here.
MenuFrame {
    id: frame

    property date now: new Date()

    preferredWidth: Math.max(220, PlatinumMetrics.even(Theme.menuTextLeft
        + PlatinumMetrics.width(frame.title) + Theme.menuGap + 16 + Theme.menuRightInset + 4))
    title: Qt.formatDate(frame.now, "dddd, MMMM d, yyyy")
    detail: {
        const hour = frame.now.getHours() % 12 || 12;
        return hour + Qt.formatTime(frame.now, ":mm") + (frame.now.getHours() < 12 ? " AM" : " PM");
    }

    MenuParts.Hint {
        rightInset: frame.rightInset
        text: "Esc close"
    }
}
