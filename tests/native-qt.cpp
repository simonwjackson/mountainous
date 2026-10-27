// Exercise the real platform theme, style plugin, font and palette. No window,
// display server, GPU, session bus or real user settings are needed.
#include <QApplication>
#include <QColor>
#include <QDebug>
#include <QFont>
#include <QFontInfo>
#include <QImage>
#include <QPainter>
#include <QPalette>
#include <QProxyStyle>
#include <QStyle>
#include <QStyleOptionButton>

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    if (argc != 4) return 2;
    QCoreApplication::processEvents();
    QStyle *style = app.style();
    while (auto proxy = dynamic_cast<QProxyStyle *>(style)) {
        style = proxy->baseStyle();
    }
    const auto actualStyle = style->objectName().toLower();
    const auto expectedStyle = QString::fromLocal8Bit(argv[1]).toLower();
    const auto font = QFontInfo(app.font()).family();
    const auto face = app.palette().color(QPalette::Window).name();
    qInfo() << "native Qt" << qVersion() << actualStyle << font << face;
    if (actualStyle != expectedStyle || font != QString::fromLocal8Bit(argv[2])
        || face != QString::fromLocal8Bit(argv[3])) return 1;
    auto indicator = [&](bool checked) {
        QImage image(32, 32, QImage::Format_ARGB32_Premultiplied);
        image.fill(app.palette().color(QPalette::Window));
        QPainter painter(&image);
        QStyleOptionButton option;
        option.rect = QRect(4, 4, 24, 24);
        option.palette = app.palette();
        option.state = QStyle::State_Enabled | QStyle::State_Active
                       | (checked ? QStyle::State_On : QStyle::State_Off);
        style->drawPrimitive(QStyle::PE_IndicatorCheckBox, &option, &painter);
        return image;
    };
    const auto off = indicator(false), on = indicator(true);
    const auto ink = app.palette().color(QPalette::Text);
    int changedInk = 0, nearest = 256;
    QColor nearestPixel;
    for (int y = 0; y < on.height(); ++y)
        for (int x = 0; x < on.width(); ++x) {
            const auto pixel = on.pixelColor(x, y);
            if (pixel == off.pixelColor(x, y)) continue;
            const int distance = qMax(qAbs(pixel.red() - ink.red()),
                qMax(qAbs(pixel.green() - ink.green()), qAbs(pixel.blue() - ink.blue())));
            if (distance < nearest) { nearest = distance; nearestPixel = pixel; }
            // The 13px embedded bitmap is scaled into the SVG's 12px image.
            // Its antialiased tick need not contain an exact palette pixel.
            if (distance <= 64) ++changedInk;
        }
    if (!changedInk) qCritical() << "Checked indicator lacks theme foreground ink"
                               << ink << "nearest" << nearestPixel << nearest;
    return changedInk ? 0 : 3;
}
