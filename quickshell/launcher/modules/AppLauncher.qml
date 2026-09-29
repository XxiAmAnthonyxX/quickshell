// modules/AppLauncher.qml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

Scope {
    id: root

    property int selectedIndex: -1

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcherPanel.visible = !launcherPanel.visible
            if (launcherPanel.visible) {
                searchInput.text = ""
                root.selectedIndex = -1
                searchInput.forceActiveFocus()
            }
        }

        function show(): void {
            launcherPanel.visible = true
            searchInput.text = ""
            root.selectedIndex = -1
            searchInput.forceActiveFocus()
        }

        function hide(): void {
            launcherPanel.visible = false
        }
    }

    ScriptModel {
        id: filteredApps
        objectProp: "id"
        values: {
            const all = [...DesktopEntries.applications.values]
            const q = searchInput.text.trim().toLowerCase()

            if (q === "") {
                return all.sort((a, b) => a.name.localeCompare(b.name))
            }

            return all.filter(d =>
                (d.name && d.name.toLowerCase().includes(q)) ||
                (d.genericName && d.genericName.toLowerCase().includes(q)) ||
                (d.comment && d.comment.toLowerCase().includes(q)) ||
                (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
                (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
            ).sort((a, b) => {
                const an = (a.name || "").toLowerCase()
                const bn = (b.name || "").toLowerCase()
                const aStarts = an.startsWith(q)
                const bStarts = bn.startsWith(q)
                if (aStarts && !bStarts) return -1
                if (!aStarts && bStarts) return 1
                return an.localeCompare(bn)
            })
        }
    }

    function launchApp(entry) {
        if (entry) {
            entry.execute()
            launcherPanel.visible = false
        }
    }

    PanelWindow {
        id: launcherPanel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Dim backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: launcherPanel.visible = false

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)
            }
        }

        // Centered launcher card
        Rectangle {
            id: launcherBox
            anchors.centerIn: parent
            width: 600
            height: 520
            radius: 16
            color: Theme.background
            border.color: Theme.muted
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // Header
                Text {
                    text: "Applications"
                    color: Theme.accentBright
                    font.pixelSize: 15
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.letterSpacing: Theme.fontLetterSpacing
                }

                // Search bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: 12
                    color: Qt.darker(Theme.background, 1.15)
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.muted
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰍉"
                            color: Theme.muted
                            font.pixelSize: 18
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.foreground
                            font.pixelSize: 15
                            font.family: Theme.fontFamily
                            font.letterSpacing: Theme.fontLetterSpacing
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                text: "Search apps..."
                                color: Theme.muted
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: root.selectedIndex = text === "" ? -1 : 0

                            Keys.onEscapePressed: launcherPanel.visible = false

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    event.accepted = true
                                    root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1)
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    event.accepted = true
                                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true
                                    if (root.selectedIndex >= 0) {
                                        const entry = filteredApps.values[root.selectedIndex]
                                        root.launchApp(entry)
                                    }
                                }
                            }
                        }
                    }
                }

                // Result count
                Text {
                    text: resultsList.count + " application" + (resultsList.count !== 1 ? "s" : "")
                    color: Theme.muted
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    font.letterSpacing: Theme.fontLetterSpacing
                }

                // Results
                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: filteredApps
                    clip: true
                    spacing: 3
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.selectedIndex
                    highlightMoveDuration: 120

                    highlight: Rectangle {
                        radius: 10
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                        visible: root.selectedIndex >= 0

                        Rectangle {
                            width: 3
                            height: 22
                            radius: 2
                            color: Theme.accentBright
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        height: 48
                        radius: 10
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Icon
                            Item {
                                width: 30
                                height: 30
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(delegateRoot.modelData.icon || "", true)
                                    visible: (delegateRoot.modelData.icon || "") !== ""
                                }

                                // Fallback letter
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Qt.darker(Theme.background, 1.2)
                                    visible: (delegateRoot.modelData.icon || "") === ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: (delegateRoot.modelData.name || "?")[0].toUpperCase()
                                        color: Theme.accentBright
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            // Name + description
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: delegateRoot.modelData.name || ""
                                    color: root.selectedIndex === delegateRoot.index
                                           ? Theme.foreground : Theme.foreground
                                    font.pixelSize: 14
                                    font.family: Theme.fontFamily
                                    font.bold: root.selectedIndex === delegateRoot.index
                                    font.letterSpacing: Theme.fontLetterSpacing
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: delegateRoot.modelData.genericName
                                          || delegateRoot.modelData.comment
                                          || ""
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                    font.letterSpacing: Theme.fontLetterSpacing
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp(delegateRoot.modelData)
                            onPositionChanged: root.selectedIndex = delegateRoot.index
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: "No applications found"
                        color: Theme.muted
                        font.pixelSize: 14
                        font.family: Theme.fontFamily
                        visible: resultsList.count === 0 && searchInput.text !== ""
                    }
                }

                // Footer hints
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Row {
                        spacing: 6
                        Rectangle {
                            width: upHint.width + 10; height: 20; radius: 5
                            color: Qt.darker(Theme.background, 1.15)
                            Text {
                                id: upHint
                                anchors.centerIn: parent
                                text: "↑↓"
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }
                        }
                        Text {
                            text: "navigate"
                            color: Theme.muted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: enterHint.width + 10; height: 20; radius: 5
                            color: Qt.darker(Theme.background, 1.15)
                            Text {
                                id: enterHint
                                anchors.centerIn: parent
                                text: "⏎"
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }
                        }
                        Text {
                            text: "launch"
                            color: Theme.muted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: escHint.width + 10; height: 20; radius: 5
                            color: Qt.darker(Theme.background, 1.15)
                            Text {
                                id: escHint
                                anchors.centerIn: parent
                                text: "esc"
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }
                        }
                        Text {
                            text: "close"
                            color: Theme.muted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
