import Quickshell
import QtQuick
import QtQuick.Layouts
import qs

ShellRoot {
    PanelWindow {
        id: bar

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 32
        color: Theme.background

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 16

            // LEFT
            Visualizer {
                Layout.alignment: Qt.AlignVCenter
            }

            // CENTER
            Item {
                Layout.fillWidth: true

                Clock {
                    anchors.centerIn: parent
                }
            }

            // RIGHT
            Media {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
