import Quickshell
import Hensou as Kit
import QtQuick
import QtQuick.Window
import "cdp-target.js" as CdpTarget
import "favicon.js" as Favicon

// Keep each surface's slot. Decode site icons at native resolution: sourceSize
// would resize the first ICO frame before we can inspect its actual pixels.
Image {
    id: root
    property var toplevel: null
    property string fallbackSource: ""
    property bool fallbackSmooth: true
    // Explicit opt-in at Platinum surfaces. Win98 retains its existing path.
    property bool platinumToken: false
    readonly property bool tokenReady: tokenImage.status === Image.Ready && tokenImage.source.toString() === token.cachedSource
    property real implicitSize: 16
    // Wayland QScreen may report integer scale 2 while the window uses 1.5.
    readonly property real pixelRatio: root.Window.window ? root.Window.window.devicePixelRatio : Screen.devicePixelRatio
    readonly property int pixels: Math.ceil(Math.min(width, height) * root.pixelRatio)
    readonly property string installedIcon: {
        DesktopEntries.applications.values;
        const appId = CdpTarget.appIdOf(root.toplevel);
        if (!/^chrome-[a-p]{32}-Default$/.test(appId)) return "";
        const entry = DesktopEntries.heuristicLookup(appId);
        return Favicon.installed(appId, entry ? entry.icon : "");
    }
    readonly property string favicon: root.installedIcon !== "" && root.installedIcon !== root.failedInstalledSource
        ? root.installedIcon : root.toplevel ? CdpBrowser.faviconFor(root.toplevel, root.pixels) : ""
    property string failedSource: ""
    property string failedInstalledSource: ""
    readonly property bool siteIcon: root.favicon !== "" && root.favicon !== root.failedSource
    readonly property bool vectorIcon: /\.svg(?:$|[?#])/i.test(root.favicon)
    property var frames: []
    readonly property int chosenFrame: Favicon.frameFor(root.frames, root.pixels)
    readonly property real nativePixels: {
        const frame = root.frames.find(function (f) { return f.frame === root.chosenFrame; });
        return frame ? frame.size : 0;
    }

    width: implicitSize
    height: implicitSize
    // Set QSize together. Resetting width/height separately reads Qt's
    // resolved other dimension and accidentally retains the old decode size.
    sourceSize: root.siteIcon && !root.vectorIcon ? Qt.size(-1, -1) : Qt.size(root.pixels, root.pixels)
    currentFrame: root.siteIcon ? root.chosenFrame : 0
    fillMode: Image.PreserveAspectFit
    source: root.tokenReady ? "" : root.siteIcon ? root.favicon : root.fallbackSource
    // Smooth only a downscale. A 16px-only icon at 1.5x has uneven pixel
    // widths, but no interpolated blur. Do not shrink or enlarge the slot.
    smooth: root.siteIcon ? Favicon.smoothFor(root.nativePixels, root.pixels) : root.fallbackSmooth
    mipmap: root.siteIcon && root.smooth
    onStatusChanged: {
        if (status !== Image.Error || !root.siteIcon || source.toString() !== root.favicon) return;
        if (root.favicon === root.installedIcon) root.failedInstalledSource = root.favicon;
        else root.failedSource = root.favicon;
    }

    PlatinumToken {
        id: token
        source: root.platinumToken && CdpTarget.isBrowser(CdpTarget.appIdOf(root.toplevel)) && root.favicon !== "" ? root.favicon : ""
        pixels: root.pixels
        theme: "platinum-" + Kit.Theme.mode
    }
    Image {
        id: tokenImage
        objectName: "platinum-token-image"
        source: token.cachedSource
        // The finished composite is never scaled. The slot stays unchanged;
        // only this child is quantised to whole device pixels at fractional DPR.
        width: root.pixels / root.pixelRatio
        height: root.pixels / root.pixelRatio
        x: Math.round((root.width - width) * root.pixelRatio / 2) / root.pixelRatio
        y: Math.round((root.height - height) * root.pixelRatio / 2) / root.pixelRatio
        sourceSize: Qt.size(-1, -1)
        smooth: false
        mipmap: false
    }

    Image {
        id: probe
        visible: false
        source: root.siteIcon ? root.favicon : ""
        onSourceChanged: {
            root.frames = [];
            currentFrame = 0;
            scan.complete = false;
        }
    }
    Timer {
        id: scan
        property bool complete: false
        interval: 1
        repeat: true
        running: !complete && probe.status === Image.Ready
        onTriggered: {
            const frames = root.frames.slice();
            frames.push({frame: probe.currentFrame, size: Math.min(probe.sourceSize.width, probe.sourceSize.height)});
            root.frames = frames;
            if (probe.currentFrame + 1 < Math.min(probe.frameCount, 64)) probe.currentFrame++;
            else complete = true;
        }
    }
}
