import QtQuick
import MyTheme 1.0

Text {
    id: clock

    property QtObject theme: Theme   // default so it always works

    property date now: new Date()

    text: Qt.formatTime(now, "HH:mm")

    color: theme.foreground
    font.family: theme.fontFamily
    font.pixelSize: theme.fontSize
    font.bold: theme.fontBold
    font.letterSpacing: theme.fontLetterSpacing

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }
}
