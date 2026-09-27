import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import MyTheme 1.0

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
    WlrLayershell.namespace: "quickshell-clipboard"

    property bool open: false
    onOpenChanged: {
        visible = open
        if (open) {
            searchField.text = ""
            refresh()
            searchField.forceActiveFocus()
        } else {
            previewText = ""
            previewImage = ""
        }
    }

    ListModel { id: fullModel }
    ListModel { id: filteredModel }

    property string previewText: ""
    property string previewImage: ""

    function refresh() {
        fullModel.clear()
        filteredModel.clear()
        getClips.running = true
    }

    function applyFilter(query) {
        filteredModel.clear()
        const q = query.trim().toLowerCase()

        for (let i = 0; i < fullModel.count; i++) {
            const item = fullModel.get(i)
            if (q === "" || item.preview.toLowerCase().includes(q)) {
                filteredModel.append(item)
            }
        }

        list.currentIndex = filteredModel.count > 0 ? 0 : -1
        updatePreview()
    }

    function updatePreview() {
        if (list.currentIndex < 0 || list.currentIndex >= filteredModel.count) {
            previewText = ""
            previewImage = ""
            return
        }

        const item = filteredModel.get(list.currentIndex)

        if (item.preview.startsWith("[[ binary data ") ||
            item.preview.toLowerCase().includes("image/")) {
            previewText = "[Image]"
            previewImage = ""
        } else {
            getFullText.command = ["sh", "-c", "echo -n '" + item.id + "' | cliphist decode"]
            getFullText.running = true
            previewImage = ""
        }
    }

    Process {
        id: getClips
        command: ["cliphist", "list"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim()
                if (!trimmed) return

                const tab = trimmed.indexOf("\t")
                if (tab === -1) return

                const id = trimmed.substring(0, tab)
                const preview = trimmed.substring(tab + 1)

                fullModel.append({ id: id, preview: preview })
            }
        }

        onRunningChanged: {
            if (!running) applyFilter(searchField.text)
        }
    }

    Process {
        id: getFullText
        stdout: StdioCollector {
            onStreamFinished: {
                previewText = this.text
            }
        }
    }

    Process {
        id: copyProc
    }

    function selectItem(index) {
        if (index < 0 || index >= filteredModel.count) return
        const item = filteredModel.get(index)

        // Safer command construction
        copyProc.command = ["sh", "-c", "echo -n '" + item.id + "' | cliphist decode | wl-copy"]
        copyProc.running = true
        root.open = false
    }

    // ---------- UI ----------
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 720
        height: 480
        radius: 16
        color: Theme.background
        border.color: Theme.muted
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search clipboard…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.letterSpacing: Theme.fontLetterSpacing
                font.bold: Theme.fontBold

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
                        selectItem(list.currentIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        list.incrementCurrentIndex()
                        updatePreview()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        list.decrementCurrentIndex()
                        updatePreview()
                        event.accepted = true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                ListView {
                    id: list
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    clip: true
                    model: filteredModel
                    currentIndex: 0
                    spacing: 4

                    onCurrentIndexChanged: updatePreview()

                    delegate: Rectangle {
                        width: list.width
                        height: 44
                        radius: 8
                        color: ListView.isCurrentItem ? Theme.accent : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            text: model.preview
                            color: ListView.isCurrentItem ? Theme.background : Theme.foreground
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.letterSpacing: Theme.fontLetterSpacing
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: list.currentIndex = index
                            onDoubleClicked: selectItem(index)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.darker(Theme.background, 1.15)
                    border.color: Theme.muted
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 14
                        visible: previewImage === "" && previewText !== "[Image]"

                        Text {
                            width: parent.width
                            text: previewText || "Select an item…"
                            color: Theme.foreground
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.letterSpacing: Theme.fontLetterSpacing
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: previewText === "[Image]" || previewImage !== ""

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🖼"
                            font.pixelSize: 32
                            color: Theme.muted
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Image preview\n(coming next)"
                            color: Theme.muted
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.open = false
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void { root.open = !root.open }
        function open(): void   { root.open = true }
        function close(): void  { root.open = false }
    }
}
