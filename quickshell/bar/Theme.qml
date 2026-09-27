pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: theme

    property var palette: ({
        background: "#140814",
        foreground: "#c4c1c4",
        muted: "#6b586b",
        accent: "#8312a3",
        accentBright: "#AF19DA"
    })

    readonly property color background: palette.background
    readonly property color foreground: palette.foreground
    readonly property color muted: palette.muted
    readonly property color accent: palette.accent
    readonly property color accentBright: palette.accentBright

// Shared typography
readonly property string fontFamily: "JetBrainsMono Nerd Font"   // or "JetBrainsMono Nerd Font Mono"
readonly property int fontSize: 12
readonly property real fontLetterSpacing: 1.2
readonly property bool fontBold: false

    property FileView walFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: theme.loadColors()
    }

    function loadColors() {
        if (!walFile.loaded)
            return

        try {
            const data = JSON.parse(walFile.text())
            const colors = data.colors || {}
            const special = data.special || {}

            palette = {
                background: special.background || colors.color0 || palette.background,
                foreground: special.foreground || colors.color15 || palette.foreground,
                muted: colors.color8 || palette.muted,
                accent: colors.color5 || palette.accent,
                accentBright: colors.color13 || palette.accentBright
            }
        } catch (error) {
            console.warn("Theme: failed to parse Pywal colors:", error)
        }
    }

    Component.onCompleted: loadColors()
}
