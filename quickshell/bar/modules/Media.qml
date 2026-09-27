import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs

Item {
    id: root

    property QtObject theme

    // Prefer a player that is currently playing, otherwise fall back to the first one
    property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) ?? players[0] ?? null
    }

    width: 238
    height: 26
    clip: true

    readonly property string displayText: root.player
        ? `${root.player.trackTitle}  //  ${root.player.trackArtist}`
        : "NO SIGNAL"

    readonly property bool needsScroll: textMetrics.width > root.width

    TextMetrics {
        id: textMetrics
        text: root.displayText
        font.family: theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.bold: root.theme.fontBold
        font.letterSpacing: root.theme.fontLetterSpacing
    }

    Row {
        id: marquee

        anchors.verticalCenter: parent.verticalCenter
        spacing: 48          // gap between the two copies

        // First copy
        Text {
            id: text1
            text: root.displayText
            color: root.player ? root.theme.foreground : root.theme.muted
            font.family: theme.fontFamily
            font.pixelSize: root.theme.fontSize
            font.bold: root.theme.fontBold
            font.letterSpacing: root.theme.fontLetterSpacing
        }

        // Second copy (only needed when scrolling)
        Text {
            visible: root.needsScroll
            text: root.displayText
            color: text1.color
            font: text1.font
        }
    }

    // Continuous seamless scroll
    NumberAnimation {
        id: scrollAnim
        target: marquee
        property: "x"
        from: 0
        to: -(text1.width + marquee.spacing)
        duration: Math.max(4000, (text1.width + marquee.spacing) * 18)
        loops: Animation.Infinite
        running: root.needsScroll
    }

    // Reset position when text changes
    onDisplayTextChanged: {
        marquee.x = 0
        if (root.needsScroll)
            scrollAnim.restart()
    }
}
