import QtQuick
import QtQuick.Controls
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
    WlrLayershell.namespace: "quickshell-wallpaper"

    property bool open: false
    property int selectedIndex: 0
    property string statusText: ""

    // Directories scanned for wallpapers (all existing dirs are merged)
    readonly property var wallpaperDirs: [
        "/mnt/backup/Files/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/wallpapers",
        Quickshell.env("HOME") + "/wallpapers",
        Quickshell.env("HOME") + "/.config/hypr/wallpapers"
    ]

    onOpenChanged: {
        visible = open
        if (open) {
            searchField.text = ""
            statusText = ""
            selectedIndex = 0
            scanWallpapers()
            searchField.forceActiveFocus()
        }
    }

    ListModel { id: fullModel }
    ListModel { id: filteredModel }

    function scanWallpapers() {
        fullModel.clear()
        filteredModel.clear()
        scanProc.running = true
    }

    function applyFilter(query) {
        filteredModel.clear()
        const q = query.trim().toLowerCase()
        for (let i = 0; i < fullModel.count; i++) {
            const item = fullModel.get(i)
            if (q === "" || item.name.toLowerCase().includes(q))
                filteredModel.append(item)
        }
        selectedIndex = filteredModel.count > 0 ? 0 : -1
    }

    function selectCurrent() {
        if (selectedIndex < 0 || selectedIndex >= filteredModel.count)
            return
        applyWallpaper(filteredModel.get(selectedIndex).path)
    }

    function columnsOfGrid() {
        // approximate columns from grid width / cell
        return Math.max(1, Math.floor((grid.width + grid.spacing) / (160 + grid.spacing)))
    }

    function applyWallpaper(path) {
        statusText = "Applying…"
        // 1) pywal colors ( -n = don't let wal set the wallpaper itself)
        // 2) set wallpaper via available backend
        // 3) optional hyprlock cache copy (matches your lock surface path)
        applyProc.command = [
            "sh", "-c",
            'WP="$1"; ' +
            'command -v wal >/dev/null 2>&1 || { echo "wal not found"; exit 1; }; ' +
            'wal -i "$WP" -n -q; ' +
            // Wallpaper backend preference: swww → hyprpaper → swaybg
            'if command -v swww >/dev/null 2>&1; then ' +
            '  if ! pgrep -x swww-daemon >/dev/null 2>&1; then swww-daemon >/dev/null 2>&1 & sleep 0.3; fi; ' +
            '  swww img "$WP" --transition-type fade --transition-duration 0.6; ' +
            'elif command -v hyprctl >/dev/null 2>&1 && hyprctl hyprpaper unload all >/dev/null 2>&1; then ' +
            '  hyprctl hyprpaper preload "$WP"; ' +
            '  for mon in $(hyprctl monitors -j 2>/dev/null | jq -r \'.[].name\'); do ' +
            '    hyprctl hyprpaper wallpaper "$mon,$WP"; ' +
            '  done; ' +
            'elif command -v swaybg >/dev/null 2>&1; then ' +
            '  pkill swaybg 2>/dev/null; swaybg -i "$WP" -m fill >/dev/null 2>&1 & ' +
            'fi; ' +
            // Keep lockscreen wallpaper in sync with your existing path
            'LOCK_CACHE="$HOME/.config/hypr/scripts/theme/cache"; ' +
            'if [ -d "$LOCK_CACHE" ]; then ' +
            '  mkdir -p "$LOCK_CACHE"; ' +
            '  cp -f "$WP" "$LOCK_CACHE/hyprlock_wallpaper.png" 2>/dev/null || true; ' +
            'fi; ' +
            // Optional: run a user theme hook if present
            'if [ -x "$HOME/.config/hypr/scripts/theme/apply.sh" ]; then ' +
            '  "$HOME/.config/hypr/scripts/theme/apply.sh" "$WP" >/dev/null 2>&1 || true; ' +
            'elif [ -x "$HOME/.config/wal/postrun" ]; then ' +
            '  "$HOME/.config/wal/postrun" >/dev/null 2>&1 || true; ' +
            'fi; ' +
            'echo ok',
            "_", path
        ]
        applyProc.running = true
    }

    Process {
        id: scanProc
        // Find image files in known wallpaper directories
        command: [
            "sh", "-c",
            'dirs=""; ' +
            'for d in "/mnt/backup/Files/Wallpapers" ' +
            '         "$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers" ' +
            '         "$HOME/wallpapers" "$HOME/.config/hypr/wallpapers"; do ' +
            '  [ -d "$d" ] && dirs="$dirs $d"; ' +
            'done; ' +
            'if [ -z "$dirs" ]; then exit 0; fi; ' +
            'find $dirs -type f \\( ' +
            '  -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o ' +
            '  -iname "*.webp" -o -iname "*.bmp" -o -iname "*.jxl" ' +
            '\\) 2>/dev/null | sort'
        ]
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (!path) return
                const name = path.split("/").pop()
                fullModel.append({ path: path, name: name })
            }
        }
        onRunningChanged: {
            if (!running)
                applyFilter(searchField.text)
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out === "ok") {
                    root.statusText = "Theme updated"
                    // Brief confirmation then close
                    closeTimer.start()
                } else {
                    root.statusText = out || "Failed"
                }
            }
        }
        onRunningChanged: {
            if (!running && root.statusText === "Applying…")
                root.statusText = "Done"
        }
    }

    Timer {
        id: closeTimer
        interval: 450
        onTriggered: root.open = false
    }

    // ---------- UI ----------
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(920, parent.width - 80)
        height: Math.min(640, parent.height - 80)
        radius: 16
        color: Theme.background
        border.color: Theme.muted
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Wallpapers"
                        color: Theme.accentBright
                        font.pixelSize: 15
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                    Text {
                        text: filteredModel.count + " image" + (filteredModel.count !== 1 ? "s" : "")
                              + (statusText !== "" ? "  ·  " + statusText : "")
                        color: Theme.muted
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                }
            }

            // Search
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search wallpapers…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.letterSpacing: Theme.fontLetterSpacing

                background: Rectangle {
                    color: Qt.darker(Theme.background, 1.25)
                    radius: 10
                    border.color: searchField.activeFocus ? Theme.accent : Theme.muted
                    border.width: 1
                }

                onTextChanged: applyFilter(text)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.open = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.selectCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        root.selectedIndex = Math.min(root.selectedIndex + root.columnsOfGrid(), filteredModel.count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.selectedIndex = Math.max(root.selectedIndex - root.columnsOfGrid(), 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        root.selectedIndex = Math.min(root.selectedIndex + 1, filteredModel.count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                        event.accepted = true
                    }
                }
            }

            // Grid
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 160
                cellHeight: 110
                model: filteredModel
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                onCurrentIndexChanged: root.selectedIndex = currentIndex

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight
                    required property int index
                    required property string path
                    required property string name

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: Qt.darker(Theme.background, 1.15)
                        border.color: root.selectedIndex === index ? Theme.accentBright : Theme.muted
                        border.width: root.selectedIndex === index ? 2 : 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: "file://" + path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            sourceSize.height: 220
                        }

                        // Filename overlay
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 22
                            color: Qt.rgba(0, 0, 0, 0.55)
                            radius: 0

                            Text {
                                anchors.fill: parent
                                anchors.margins: 4
                                text: name
                                color: Theme.foreground
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = index
                            onClicked: root.selectedIndex = index
                            onDoubleClicked: root.applyWallpaper(path)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: filteredModel.count === 0
                    text: fullModel.count === 0
                          ? "No wallpapers found\nExpected: /mnt/backup/Files/Wallpapers"
                          : "No matches"
                    color: Theme.muted
                    font.pixelSize: 13
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "↑↓←→ move  ·  ⏎ / double-click apply  ·  esc close"
                    color: Theme.muted
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    font.letterSpacing: Theme.fontLetterSpacing
                    Layout.fillWidth: true
                }

                Rectangle {
                    height: 28
                    width: applyLbl.width + 20
                    radius: 8
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    border.color: Theme.accent
                    border.width: 1
                    opacity: root.selectedIndex >= 0 ? 1 : 0.4

                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: "Apply + theme"
                        color: Theme.accentBright
                        font.pixelSize: 12
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectedIndex >= 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCurrent()
                    }
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
            color: Qt.rgba(0, 0, 0, 0.5)
        }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void   { root.open = true }
        function toggle(): void { root.open = !root.open }
        function close(): void  { root.open = false }
        function refresh(): void {
            if (root.open) root.scanWallpapers()
        }
    }
}
