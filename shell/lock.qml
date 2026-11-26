//@ pragma UseQApplication
// Isolated session Lock process: runs ext-session-lock independently of Sky and Core so a shell crash or
// restart can never strand the session locked. Launched by `takumi lock`; exits cleanly once unlocked.
import QtQuick
import Quickshell
import "Look"
import "Sources"
import "Lock"

ShellRoot {
    id: root
    Niri { id: niriService }
    Poll { id: pollService }
    Lock {
        id: lockScreen
        poll: pollService
        niri: niriService
        Component.onCompleted: lock()
        onFinished: Qt.quit()
    }
}
