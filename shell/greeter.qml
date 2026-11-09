//@ pragma UseQApplication
// Takumi's login screen: the Lock's face on the Sky, for the person who owns this computer. greetd runs it
// through takumi greeter (in cage) as the greeter user; after a good password it starts the session with
// takumi session start. See docs/shell.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "Look"
import "Parts"
import "Sky"

ShellRoot {
    id: root
    property string user: ""
    property string secret: ""
    property bool busy: false
    property bool failed: false
    property bool prompted: false

    // Whose computer this is: the first account with a home under /home.
    Process {
        running: true
        command: ["awk", "-F:", "$3 >= 1000 && $3 < 60000 && $6 ~ /^\\/home\\// { print $1; exit }", "/etc/passwd"]
        stdout: StdioCollector { onStreamFinished: { root.user = this.text.trim(); root.begin(); } }
    }

    function begin() { if (user) { prompted = false; Greetd.createSession(user); } }
    function submit(s) {
        if (busy || !s) return;
        secret = s; busy = true; failed = false;
        if (prompted) { prompted = false; Greetd.respond(secret); }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) return;
            root.prompted = true;
            if (root.busy) { root.prompted = false; Greetd.respond(root.secret); }
        }
        function onAuthFailure(message) {
            root.busy = false; root.failed = true; root.secret = "";
            Greetd.cancelSession();
            root.begin();
        }
        function onReadyToLaunch() { root.secret = ""; Greetd.launch(["takumi", "session", "start"]); }
        function onError(error) { console.warn("greetd:", error); root.busy = false; root.failed = true; }
    }

    // cage shows one window, full screen. The first login screen since the computer started opens on the
    // boot splash's picture (Parts/Arrival.qml; takumi greeter says which one this is).
    FloatingWindow {
        id: win
        color: Theme.background
        // The sky is painted behind the splash picture once that is on screen, so the first picture
        // comes as soon as the window does.
        SkyCanvas { id: sky; anchors.fill: parent; visible: arrival.ready }
        LockFace {
            id: face
            anchors.fill: parent
            user: root.user
            busy: root.busy
            failed: root.failed
            hint: "Password"
            emblemShown: arrival.landed
            reveal: arrival.reveal
            onSubmitted: s => root.submit(s)
        }
        Arrival {
            id: arrival
            anchors.fill: parent
            target: face.emblem
            fromBoot: Quickshell.env("TAKUMI_GREETER_FROM_BOOT") === "1"
            ready: win.backingWindowVisible
            backdropReady: sky.drawn
        }
    }

    // The computer reached a usable screen: a room on its first start counts as good (takumi room health).
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", ": > /run/takumi/desktop-ready 2>/dev/null || true"])
}
