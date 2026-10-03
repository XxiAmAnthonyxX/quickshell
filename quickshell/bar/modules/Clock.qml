import QtQuick
import qs

Text {
    id: clock

    property date now: new Date()

    text: Qt.formatTime(now, "HH:mm")

    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    font.letterSpacing: Theme.fontLetterSpacing

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }
}
