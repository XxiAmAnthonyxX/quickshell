import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import MyTheme 1.0

Rectangle {
    id: root
    required property var context

    color: Theme.background

    Image {
        anchors.fill: parent
        source: Quickshell.env("HOME") + "/.config/hypr/scripts/theme/cache/hyprlock_wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    // Dark overlay so text stays readable
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    opacity: 0
    Component.onCompleted: {
        fadeIn.start()
        passwordInput.forceActiveFocus()
    }
    NumberAnimation on opacity {
        id: fadeIn
        to: 1
        duration: 450
        easing.type: Easing.OutCubic
    }

    // Clock + date
    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18
        spacing: 6

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 92
            font.weight: Font.Light
            font.family: Theme.fontFamily
            color: Theme.foreground
            text: Qt.formatTime(new Date(), "HH:mm")

            Timer {
                running: true
                interval: 1000
                repeat: true
                onTriggered: timeText.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 22
            font.family: Theme.fontFamily
            color: Theme.muted
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
        }
    }

    // Media
    RowLayout {
        id: mediaRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: passwordCol.top
        anchors.bottomMargin: 48
        spacing: 16
        visible: Mpris.players.values.length > 0

        property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

        Column {
            spacing: 2
            Text {
                text: mediaRow.player ? (mediaRow.player.trackTitle || "Unknown") : ""
                color: Theme.foreground
                font.pixelSize: 15
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                width: 220
            }
            Text {
                text: mediaRow.player ? (mediaRow.player.trackArtist || "") : ""
                color: Theme.muted
                font.pixelSize: 13
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                width: 220
            }
        }

        Row {
            spacing: 12

            Text {
                text: "󰒮"
                font.pixelSize: 20
                color: Theme.muted
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mediaRow.player?.canGoPrevious) mediaRow.player.previous()
                }
            }

            Text {
                text: {
                    if (!mediaRow.player) return "󰐊"
                    return mediaRow.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                }
                font.pixelSize: 24
                color: Theme.foreground
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!mediaRow.player) return
                        if (mediaRow.player.playbackState === MprisPlaybackState.Playing)
                            mediaRow.player.pause()
                        else
                            mediaRow.player.play()
                    }
                }
            }

            Text {
                text: "󰒭"
                font.pixelSize: 20
                color: Theme.muted
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mediaRow.player?.canGoNext) mediaRow.player.next()
                }
            }
        }
    }

    // Password area
    Column {
        id: passwordCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 40
        spacing: 14

        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            property int count: Math.min(root.context.currentText.length, 12)

            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    width: 10
                    height: 10
                    radius: 5
                    color: index < dots.count ? Theme.foreground : Theme.muted
                    scale: index < dots.count ? 1.15 : 1.0

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }

        TextInput {
            id: passwordInput
            width: 1
            height: 1
            opacity: 0
            focus: true
            echoMode: TextInput.Password
            enabled: !root.context.unlockInProgress

            onTextChanged: root.context.currentText = text
            onAccepted: root.context.tryUnlock()

            Keys.onEscapePressed: {
                text = ""
                root.context.currentText = ""
            }

            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    if (passwordInput.text !== root.context.currentText)
                        passwordInput.text = root.context.currentText
                }
                function onShowFailureChanged() {
                    if (root.context.showFailure)
                        shake.start()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (root.context.unlockInProgress) return "Verifying…"
                if (root.context.showFailure) return "Wrong password"
                return "Enter password"
            }
            color: root.context.showFailure ? "#ff6b6b" : Theme.muted
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: passwordCol; property: "anchors.horizontalCenterOffset"; to: 18; duration: 50 }
        NumberAnimation { target: passwordCol; property: "anchors.horizontalCenterOffset"; to: -18; duration: 50 }
        NumberAnimation { target: passwordCol; property: "anchors.horizontalCenterOffset"; to: 12; duration: 50 }
        NumberAnimation { target: passwordCol; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
        NumberAnimation { target: passwordCol; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: passwordInput.forceActiveFocus()
    }
}
