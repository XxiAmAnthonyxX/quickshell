import Quickshell
import QtQuick
import QtQuick.Layouts
import MyTheme 1.0

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

            // LEFT – add later when you write Workspaces.qml
            // Modules.Workspaces { Layout.alignment: Qt.AlignVCenter }

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

            // Optional visualizer (uncomment if you want it)
            // Modules.Visualizer {
            //     Layout.alignment: Qt.AlignVCenter
            //     theme: Theme
            // }
        }
    }
}
