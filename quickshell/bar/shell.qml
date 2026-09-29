import Quickshell
import QtQuick
import QtQuick.Layouts

import "modules" as Modules

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
            Modules.Visualizer {
                Layout.alignment: Qt.AlignVCenter
                theme: Theme
            }

            // CENTER
            Item {
                Layout.fillWidth: true

                Modules.Clock {
                    anchors.centerIn: parent
                    theme: Theme
                }
            }

            // RIGHT
            Modules.Media {
                Layout.alignment: Qt.AlignVCenter
                theme: Theme
            }
        }
    }
}
