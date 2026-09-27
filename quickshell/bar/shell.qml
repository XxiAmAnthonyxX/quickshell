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
        color: "#202020"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 16

            // LEFT
            Modules.Workspaces {
                Layout.alignment: Qt.AlignVCenter
            }

            // CENTER
            Item {
                Layout.fillWidth: true

                Modules.Clock {
                    anchors.centerIn: parent
                }
            }

            // RIGHT
            Modules.Media {
                Layout.alignment: Qt.AlignVCenter
            }

            Modules.Volume {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}

