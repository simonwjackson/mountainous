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
    // Explicit opt-in at Platinum surfaces. Memphis retains its existing path.
    property bool platinumToken: false
    readonly property bool tokenReady: tokenImage.status === Image.Ready && tokenImage.source.toString() === token.cachedSource
    property real implicitSize: 16
    // Device px. Draw theme art (fallbackSource) at exactly this size,
    // centred in the slot on whole device pixels and never scaled: the
    // Control Strip's box, where Platinum's 32 px art is drawn 1:1 at scale
    // 1.5 (strip-plan.js tileGeometry). 0: theme art fills the slot.
    property int artPixels: 0
    // Device px. > 0 (the Control Strip): the site icon's token has opaque
    // bounds this size (PlatinumToken.extent), and nothing else is shown
    // scaled. Until it arrives, or with no site icon, the theme art
    // (fallbackSource: the strip's build-time token) draws 1:1 at artPixels.
    property int opticalExtent: 0
    readonly property bool boxedArt: root.artPixels > 0 && (root.opticalExtent > 0 ? !root.tokenReady : !root.siteIcon)
    // Wayland QScreen may report integer scale 2 while the window uses 1.5.
    readonly property real pixelRatio: root.Window.window ? root.Window.window.devicePixelRatio : Screen.devicePixelRatio
    // (Less a hair of float error: 20.8 logical at 1.25 is 26 px, not 27.)
    readonly property int pixels: Math.ceil(Math.min(width, height) * root.pixelRatio - 1e-6)
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
    source: root.tokenReady || root.boxedArt ? "" : root.siteIcon ? root.favicon : root.fallbackSource
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
        extent: root.opticalExtent
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
        id: artImage
        objectName: "platinum-art-image"
        visible: root.boxedArt
        source: root.boxedArt ? root.fallbackSource : ""
        width: root.artPixels / root.pixelRatio
        height: root.artPixels / root.pixelRatio
        x: Math.round((root.width * root.pixelRatio - root.artPixels) / 2) / root.pixelRatio
        y: Math.round((root.height * root.pixelRatio - root.artPixels) / 2) / root.pixelRatio
        // An icon-theme URL is scalable: Qt asks the provider for this size
        // times the ratio, artPixels, and the theme's 32 px art comes back
        // unscaled.
        sourceSize: Qt.size(width, height)
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
