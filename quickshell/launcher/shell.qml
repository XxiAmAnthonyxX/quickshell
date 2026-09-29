// shell.qml
//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs

ShellRoot {
    // Force Theme singleton to load early so Pywal colors are ready

    AppLauncher {}
}
