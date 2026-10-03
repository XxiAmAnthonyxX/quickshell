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
    WlrLayershell.namespace: "quickshell-recorder"

    property bool open: false
    property bool recording: false
    property string lastPath: ""
    property int selectedIndex: 0

    // "both" | "system" | "mic" | "none"
    property string audioMode: "both"

    onOpenChanged: {
        visible = open
        if (open) {
            checkRecording.running = true
            panel.forceActiveFocus()
        }
    }

    readonly property var regionActions: [
        { id: "fullscreen", label: "Fullscreen",  icon: "󰹑", hint: "Record entire screen" },
        { id: "area",       label: "Select area", icon: "󰆞", hint: "Drag region to record" },
        { id: "window",     label: "Select window", icon: "󰖯", hint: "Active window region" }
    ]

    readonly property var audioActions: [
        { id: "both",   label: "System + mic", icon: "󰕾", hint: "Desktop audio and microphone" },
        { id: "system", label: "System only",  icon: "󰽢", hint: "Monitor of default sink" },
        { id: "mic",    label: "Mic only",     icon: "󰍬", hint: "Default input source" },
        { id: "none",   label: "No audio",     icon: "󰝟", hint: "Video only" }
    ]

    // region rows (0–2) then audio rows (3–6)
    readonly property int totalItems: regionActions.length + audioActions.length

    function openMenu() {
        selectedIndex = 0
        open = true
    }

    function toggle() {
        if (recording) {
            stopRecording()
            return
        }
        open = !open
        if (open) selectedIndex = 0
    }

    function stopRecording() {
        stopProc.running = true
        recording = false
        open = false
    }

    function isRegion(index) {
        return index < regionActions.length
    }

    function currentId() {
        if (selectedIndex < regionActions.length)
            return regionActions[selectedIndex].id
        return audioActions[selectedIndex - regionActions.length].id
    }

    function onActivate() {
        if (isRegion(selectedIndex)) {
            runRecord(regionActions[selectedIndex].id)
        } else {
            audioMode = audioActions[selectedIndex - regionActions.length].id
        }
    }

    function runRecord(regionId) {
        open = false

        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss")
        const out = Quickshell.env("HOME") + "/Videos/recording_" + stamp + ".mp4"
        lastPath = out

        // Geometry (quoted so "x,y WxH" stays one argument)
        let geomCmd = ""
        if (regionId === "area") {
            geomCmd = 'GEOM=$(slurp) || exit 0; '
        } else if (regionId === "window") {
            geomCmd = 'GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r \'"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\') || exit 0; '
        } else {
            geomCmd = 'GEOM=""; '
        }

        // Audio: wf-recorder takes a single -a device.
        // both  → default source (mic); also try to use a combined virtual source if present
        // system → default sink monitor
        // mic   → default source
        // none  → no -a
        let audioCmd = ""
        if (audioMode === "none") {
            audioCmd = 'AUDIO_ARGS=""; '
        } else if (audioMode === "system") {
            audioCmd =
                'SINK=$(pactl get-default-sink 2>/dev/null); ' +
                'AUDIO_ARGS="--audio=${SINK}.monitor"; '
        } else if (audioMode === "mic") {
            audioCmd =
                'SRC=$(pactl get-default-source 2>/dev/null); ' +
                'AUDIO_ARGS="--audio=${SRC}"; '
        } else {
            // both: prefer a sink/source named *combined* / *Combined* / *Virtual*, else default source
            // (PipeWire users can create a combined source; otherwise falls back to mic)
            audioCmd =
                'COMBINED=$(pactl list short sources 2>/dev/null | awk \'/combined|Combined|Virtual/ {print $2; exit}\'); ' +
                'if [ -n "$COMBINED" ]; then AUDIO_ARGS="--audio=$COMBINED"; ' +
                'else SRC=$(pactl get-default-source 2>/dev/null); AUDIO_ARGS="--audio=${SRC}"; fi; '
        }

        recProc.command = [
            "sh", "-c",
            'mkdir -p "$HOME/Videos"; ' +
            'if pgrep -x wf-recorder >/dev/null 2>&1; then pkill -INT wf-recorder; exit 0; fi; ' +
            geomCmd +
            audioCmd +
            'if [ -n "$GEOM" ]; then ' +
            '  wf-recorder -g "$GEOM" $AUDIO_ARGS -f "' + out + '" & ' +
            'else ' +
            '  wf-recorder $AUDIO_ARGS -f "' + out + '" & ' +
            'fi; ' +
            'echo $! > /tmp/quickshell-wf-recorder.pid'
        ]
        recProc.running = true
        recording = true
    }

    Process { id: recProc }
    Process {
        id: stopProc
        command: ["sh", "-c", "pkill -INT wf-recorder 2>/dev/null; rm -f /tmp/quickshell-wf-recorder.pid"]
    }
    Process {
        id: checkRecording
        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recording = (this.text.trim() === "1")
            }
        }
    }

    // Poll recording state while menu is open
    Timer {
        interval: 1500
        running: root.open
        repeat: true
        onTriggered: checkRecording.running = true
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 380
        // header + 3 region + divider + 4 audio + footer + stop row
        height: contentCol.implicitHeight + 36
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
                root.selectedIndex = Math.min(root.selectedIndex + 1, root.totalItems - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.onActivate()
                event.accepted = true
            } else if (event.key === Qt.Key_1) {
                root.runRecord("fullscreen"); event.accepted = true
            } else if (event.key === Qt.Key_2) {
                root.runRecord("area"); event.accepted = true
            } else if (event.key === Qt.Key_3) {
                root.runRecord("window"); event.accepted = true
            } else if (event.key === Qt.Key_S && root.recording) {
                root.stopRecording(); event.accepted = true
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            // Header
            Column {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    width: parent.width
                    Text {
                        text: "Screen record"
                        color: Theme.accentBright
                        font.pixelSize: 15
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: Theme.fontLetterSpacing
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: root.recording
                        height: 22
                        width: recBadge.width + 14
                        radius: 6
                        color: Qt.rgba(1, 0.25, 0.25, 0.2)
                        border.color: "#ff6b6b"
                        border.width: 1
                        Text {
                            id: recBadge
                            anchors.centerIn: parent
                            text: "● REC"
                            color: "#ff6b6b"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: root.recording
                          ? "Recording… press Stop or bind stop IPC"
                          : "Region + audio, then start"
                    color: Theme.muted
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    font.letterSpacing: Theme.fontLetterSpacing
                }
            }

            // Region section
            Text {
                text: "REGION"
                color: Theme.muted
                font.pixelSize: 10
                font.family: Theme.fontFamily
                font.letterSpacing: 1.5
                font.bold: true
                Layout.topMargin: 4
            }

            Repeater {
                model: root.regionActions

                Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    height: 48
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
                        spacing: 12

                        Text {
                            text: modelData.icon
                            color: root.selectedIndex === index ? Theme.accentBright : Theme.muted
                            font.pixelSize: 18
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                text: modelData.label
                                color: Theme.foreground
                                font.pixelSize: 13
                                font.family: Theme.fontFamily
                                font.bold: root.selectedIndex === index
                                font.letterSpacing: Theme.fontLetterSpacing
                            }
                            Text {
                                text: modelData.hint
                                color: Theme.muted
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
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
                        onClicked: root.runRecord(modelData.id)
                    }
                }
            }

            // Audio section
            Text {
                text: "AUDIO"
                color: Theme.muted
                font.pixelSize: 10
                font.family: Theme.fontFamily
                font.letterSpacing: 1.5
                font.bold: true
                Layout.topMargin: 6
            }

            Repeater {
                model: root.audioActions

                Rectangle {
                    required property var modelData
                    required property int index

                    readonly property int globalIndex: index + root.regionActions.length

                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: root.selectedIndex === globalIndex
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                           : "transparent"
                    border.color: root.audioMode === modelData.id ? Theme.accent : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: modelData.icon
                            color: root.audioMode === modelData.id ? Theme.accentBright : Theme.muted
                            font.pixelSize: 16
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.label
                            color: Theme.foreground
                            font.pixelSize: 13
                            font.family: Theme.fontFamily
                            font.bold: root.audioMode === modelData.id
                            font.letterSpacing: Theme.fontLetterSpacing
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Selection indicator
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root.audioMode === modelData.id ? Theme.accentBright : Theme.muted
                            opacity: root.audioMode === modelData.id ? 1 : 0.35
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = globalIndex
                        onClicked: root.audioMode = modelData.id
                    }
                }
            }

            // Stop + footer
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Rectangle {
                    visible: root.recording
                    height: 28
                    width: stopLbl.width + 20
                    radius: 8
                    color: Qt.rgba(1, 0.3, 0.3, 0.2)
                    border.color: "#ff6b6b"
                    border.width: 1

                    Text {
                        id: stopLbl
                        anchors.centerIn: parent
                        text: "Stop recording"
                        color: "#ff6b6b"
                        font.pixelSize: 12
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopRecording()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.recording
                          ? "s stop  ·  esc close"
                          : "↑↓  ·  ⏎ start / set audio  ·  esc"
                    color: Theme.muted
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    font.letterSpacing: Theme.fontLetterSpacing
                    horizontalAlignment: Text.AlignRight
                }
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
        target: "recorder"

        function open(): void   { root.openMenu() }
        function toggle(): void { root.toggle() }
        function stop(): void   { root.stopRecording() }
        function close(): void  { root.open = false }
    }
}
