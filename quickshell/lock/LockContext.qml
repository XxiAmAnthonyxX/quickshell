import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs

Scope {
    id: root
    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "") return
        unlockInProgress = true
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired)
                respond(root.currentText)
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root.currentText = ""
                root.showFailure = true
            }
            root.unlockInProgress = false
        }
    }
}
