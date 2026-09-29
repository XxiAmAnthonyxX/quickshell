import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs

Item {
    id: root

    property QtObject theme: Theme

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
        font.pixelSize: theme.fontSize
        font.bold: theme.fontBold
        font.letterSpacing: theme.fontLetterSpacing
    }

    Row {
        id: marquee
        anchors.verticalCenter: parent.verticalCenter
        spacing: 48

        Text {
            id: text1
            text: root.displayText
            color: root.player ? theme.foreground : theme.muted
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.bold: theme.fontBold
            font.letterSpacing: theme.fontLetterSpacing
        }

        Text {
            visible: root.needsScroll
            text: root.displayText
            color: text1.color
            font: text1.font
        }
    }

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

    onDisplayTextChanged: {
        marquee.x = 0
        if (root.needsScroll)
            scrollAnim.restart()
    }
}
