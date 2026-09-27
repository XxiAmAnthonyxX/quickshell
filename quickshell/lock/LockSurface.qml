import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs

Rectangle {
    id: root
    required property var context

    color: "#0a0a0c"

    Image {
        anchors.fill: parent
        source: Quickshell.env("HOME") + "/.config/hypr/scripts/theme/cache/hyprlock_wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#99000000"
    }

    // ... rest of the lock UI (clock, media, password) stays the same

    // Fade-in
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
            color: "#f0f0f5"
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
            color: "#a0a0b0"
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
        }
    }

    // Media (MPRIS)
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
                color: "#e8e8f0"
                font.pixelSize: 15
                elide: Text.ElideRight
                width: 220
            }
            Text {
                text: mediaRow.player ? (mediaRow.player.trackArtist || "") : ""
                color: "#888899"
                font.pixelSize: 13
                elide: Text.ElideRight
                width: 220
            }
        }

        Row {
            spacing: 12

            Text {
                text: "󰒮"
                font.pixelSize: 20
                color: "#c0c0d0"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (mediaRow.player && mediaRow.player.canGoPrevious)
                            mediaRow.player.previous()
                    }
                }
            }

            Text {
                text: {
                    if (!mediaRow.player)
                        return "󰐊"
                    return mediaRow.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                }
                font.pixelSize: 24
                color: "#e0e0f0"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!mediaRow.player)
                            return
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
                color: "#c0c0d0"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (mediaRow.player && mediaRow.player.canGoNext)
                            mediaRow.player.next()
                    }
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

        // Dots
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
                    color: index < dots.count ? "#f0f0f5" : "#404050"
                    scale: index < dots.count ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 120 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }
            }
        }

        // Hidden real input
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
                if (root.context.unlockInProgress)
                    return "Verifying…"
                if (root.context.showFailure)
                    return "Wrong password"
                return "Enter password"
            }
            color: root.context.showFailure ? "#ff6b6b" : "#9090a0"
            font.pixelSize: 14
        }
    }

    // Shake on failure
    SequentialAnimation {
        id: shake
        NumberAnimation {
            target: passwordCol
            property: "anchors.horizontalCenterOffset"
            to: 18
            duration: 50
        }
        NumberAnimation {
            target: passwordCol
            property: "anchors.horizontalCenterOffset"
            to: -18
            duration: 50
        }
        NumberAnimation {
            target: passwordCol
            property: "anchors.horizontalCenterOffset"
            to: 12
            duration: 50
        }
        NumberAnimation {
            target: passwordCol
            property: "anchors.horizontalCenterOffset"
            to: -12
            duration: 50
        }
        NumberAnimation {
            target: passwordCol
            property: "anchors.horizontalCenterOffset"
            to: 0
            duration: 50
        }
    }

    // Click → focus
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: passwordInput.forceActiveFocus()
    }
}
