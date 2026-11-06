import QtQuick
import QtTest
import Hensou

TestCase {
    name: "KitPaletteProbe"

    function test_export() {
        // Exercise the public functions in the real QML engine, not their
        // source spelling. Theme is the actual kit singleton, not a stub.
        const themes = [{ id: "platinum", tokens: PlatinumTokens },
                        { id: "memphis", tokens: MemphisTokens }];
        for (const theme of themes) {
            for (const choice of theme.tokens.appearances) {
                Theme.name = theme.id;
                Theme.appearance = choice.id;
                Theme.mode = choice.dark ? "dark" : "light";
                const palettes = {};
                for (const extra of [false, true]) {
                    Theme.extraState = extra ? "on" : "off";
                    palettes[extra ? "on" : "off"] = theme.tokens.palette(choice.id, extra);
                }
                console.info("HENSOU_PALETTE:" + JSON.stringify({
                    theme: theme.id, id: choice.id, mode: choice.dark ? "dark" : "light", palettes: palettes
                }));
            }
        }
    }
}
