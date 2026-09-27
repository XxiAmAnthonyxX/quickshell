import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs

Item {
    id: root

    property QtObject theme

    // Look & feel
    property int bars: 64
    property int barWidth: 4
    property int spacing: 3
    property real maxHeight: 22

    width: bars * (barWidth + spacing) - spacing
    height: 28

    property real peak: 0
    property real animationPhase: 0
    property var values: Array(bars).fill(0)

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PwNodePeakMonitor {
        node: Pipewire.defaultAudioSink
        onPeaksChanged: {
            if (!peaks?.length) {
                root.peak = 0
                return
            }

            let maxPeak = 0
            for (let i = 0; i < peaks.length; i++)
                maxPeak = Math.max(maxPeak, peaks[i])

            root.peak = Math.max(0, Math.min(1, maxPeak))

            // Soft bell curve + gentle traveling wave
            root.values = Array.from({ length: root.bars }, (_, i) => {
                const t = i / Math.max(1, root.bars - 1)
                const center = 1 - Math.pow(Math.abs(t - 0.5) * 1.8, 1.6)
                const wave = 0.78 + 0.22 * Math.sin(t * Math.PI * 4 + root.animationPhase)
                return root.peak * Math.max(0.08, center * wave)
            })
        }
    }

    NumberAnimation on animationPhase {
        running: root.peak > 0.01
        from: 0
        to: Math.PI * 2
        duration: 1100
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    // Full-height container so verticalCenter works correctly
    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.bars

            Rectangle {
                required property int index

                width: root.barWidth
                height: Math.max(3, (root.values[index] || 0) * root.maxHeight)

                // Bars grow from the center
                anchors.verticalCenter: parent.verticalCenter

                radius: width / 2          // fully rounded ends
                color: root.theme.foreground
                opacity: 0.25 + Math.min(0.75, (root.values[index] || 0) * 1.1)

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
