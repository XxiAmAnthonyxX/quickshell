import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"

    property bool open: false
    property int selectedIndex: 0

    onOpenChanged: {
        visible = open
        if (open)
            panel.forceActiveFocus()
    }

    readonly property var actions: [
        { id: "fullscreen", label: "Fullscreen", icon: "󰹑", hint: "Entire screen → clipboard + file" },
        { id: "area",       label: "Select area", icon: "󰆞", hint: "Drag a region" },
        { id: "window",     label: "Select window", icon: "󰖯", hint: "Active window" }
    ]

    function openMenu() {
        selectedIndex = 0
        open = true
    }

    function toggle() {
        open = !open
        if (open) selectedIndex = 0
    }

    function runAction(id) {
        open = false

        const target = id === "fullscreen" ? "screen"
                      : id === "area"       ? "area"
                      :                       "active"

        // Raw tools: grimblast preferred (no --notify), else grim + slurp + hyprctl
        shotProc.command = [
            "sh", "-c",
            'mkdir -p "$HOME/Pictures/Screenshots"; ' +
            'if command -v grimblast >/dev/null 2>&1; then ' +
            '  grimblast copysave ' + target + '; ' +
            'else ' +
            '  case "' + target + '" in ' +
            '    screen) grim - | tee "$HOME/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png" | wl-copy -t image/png ;; ' +
            '    area)   grim -g "$(slurp)" - | tee "$HOME/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png" | wl-copy -t image/png ;; ' +
            '    active) ' +
            '      geom=$(hyprctl activewindow -j 2>/dev/null | jq -r \'"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\'); ' +
            '      grim -g "$geom" - | tee "$HOME/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png" | wl-copy -t image/png ;; ' +
            '  esac; ' +
            'fi'
        ]
        shotProc.running = true
    }

    Process { id: shotProc }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 360
        height: headerCol.height + listCol.implicitHeight + 36
        radius: 16
        color: Theme.background
        border.color: Theme.muted
        border.width: 1
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.open = false
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                root.selectedIndex = Math.min(root.selectedIndex + 1, root.actions.length - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.runAction(root.actions[root.selectedIndex].id)
                event.accepted = true
            } else if (event.key === Qt.Key_1) {
                root.runAction("fullscreen"); event.accepted = true
            } else if (event.key === Qt.Key_2) {
                root.runAction("area"); event.accepted = true
            } else if (event.key === Qt.Key_3) {
                root.runAction("window"); event.accepted = true
            }
        }

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            Column {
                id: headerCol
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Screenshot"
                    color: Theme.accentBright
                    font.pixelSize: 15
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.letterSpacing: Theme.fontLetterSpacing
                }

                Text {
                    text: "Choose what to capture"
                    color: Theme.muted
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    font.letterSpacing: Theme.fontLetterSpacing
                }
            }

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    height: 52
                    radius: 10
                    color: root.selectedIndex === index
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                           : "transparent"
                    border.color: root.selectedIndex === index ? Theme.accent : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        Text {
                            text: modelData.icon
                            color: root.selectedIndex === index ? Theme.accentBright : Theme.muted
                            font.pixelSize: 20
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: modelData.label
                                color: Theme.foreground
                                font.pixelSize: 14
                                font.family: Theme.fontFamily
                                font.bold: root.selectedIndex === index
                                font.letterSpacing: Theme.fontLetterSpacing
                            }

                            Text {
                                text: modelData.hint
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                                font.letterSpacing: Theme.fontLetterSpacing
                            }
                        }

                        Text {
                            text: String(index + 1)
                            color: Theme.muted
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: root.runAction(modelData.id)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "↑↓ navigate  ·  ⏎ select  ·  esc close"
                color: Theme.muted
                font.pixelSize: 10
                font.family: Theme.fontFamily
                font.letterSpacing: Theme.fontLetterSpacing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.open = false

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    IpcHandler {
        target: "screenshot"

        function open(): void   { root.openMenu() }
        function toggle(): void { root.toggle() }
        function close(): void  { root.open = false }
    }
}
