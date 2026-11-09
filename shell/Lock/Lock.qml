// The lock screen: the Lock face on the sky. A Wayland session lock (ext-session-lock) checked by PAM
// through /etc/pam.d/takumi-lock. With fingerprint unlock on and the lid open, a second PAM conversation
// listens to the sensor through /etc/pam.d/takumi-lock-finger at the same time, so typing never waits for
// it: the first to succeed unlocks and stops the other. Three wrong fingers, and the Lock waits for the
// password until it locks again (docs/security.md).
// If the shell dies while locked, niri keeps the session locked; restart the shell from a TTY
// (`systemctl --user restart takumi-shell`) and lock again to get the field back.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Look"
import "../Parts"
import "../Sky"

Scope {
    id: root
    property var poll: null
    property var niri: null
    property bool locked: false
    property string secret: ""
    property bool busy: false
    property bool failed: false
    property string lockout: ""            // "Locked for 2 minutes": pam_faillock's ten tries ran out
    // The finger: listening while the sensor waits; misses count wrong fingers this time locked.
    property bool fingerOn: false
    property int fingerMisses: 0
    property bool fingerMissed: false      // the last finger was wrong: the mark shakes and says so
    property int fingerRetries: 0

    function lock() {
        secret = ""; failed = false; busy = false; locked = true;
        fingerMisses = 0; fingerMissed = false; fingerRetries = 0;
        if (!fingerCheck.running) fingerCheck.running = true;
    }
    function submit(s) { if (busy || !s) return; secret = s; busy = true; failed = false; lockout = ""; pam.start(); }
    function unlocked() {
        if (pam.active) pam.abort();
        if (finger.active) finger.abort();
        fingerOn = false; retry.stop();
        locked = false;
    }

    PamContext {
        id: pam
        config: "takumi-lock"
        // pam_faillock says "The account is locked due to 10 failed logins." and "(2 minutes left to unlock)".
        onPamMessage: {
            const m = String(this.message ?? "");
            const left = m.match(/\((\d+) minutes? left to unlock\)/);
            if (left) root.lockout = "Locked for " + left[1] + (left[1] === "1" ? " minute" : " minutes");
            else if (/account is locked/i.test(m) && root.lockout === "") root.lockout = "Locked for a little while";
            if (this.responseRequired) this.respond(root.secret);
        }
        onCompleted: result => {
            root.busy = false; root.secret = "";
            if (result === PamResult.Success) root.unlocked();
            else root.failed = true;
        }
    }

    // Whether a finger can unlock now: fprintd, a reader, a finger enrolled for you, the lid open.
    Process {
        id: fingerCheck
        command: ["takumi", "security", "fingerprint", "--check"]
        onExited: code => { if (code === 0 && root.locked) root.listen(); }
    }
    function listen() {
        if (!locked || finger.active || fingerMisses >= 3) return;
        fingerOn = true;
        finger.start();
    }
    PamContext {
        id: finger
        config: "takumi-lock-finger"
        // pam_fprintd says what is happening; an error message is a finger it did not know.
        onPamMessage: {
            if (this.messageIsError) { root.fingerMisses++; root.fingerMissed = true; missedReset.restart(); }
            if (this.responseRequired) this.respond("");
        }
        onCompleted: result => {
            root.fingerOn = false;
            if (result === PamResult.Success) { root.unlocked(); return; }
            // Three wrong fingers end it; anything else (the reader waking from sleep, busy) is tried again.
            if (root.locked && root.fingerMisses < 3 && root.fingerRetries < 3) { root.fingerRetries++; retry.restart(); }
        }
    }
    Timer { id: retry; interval: 1500; onTriggered: root.listen() }
    Timer { id: missedReset; interval: 1800; onTriggered: root.fingerMissed = false }

    WlSessionLock {
        locked: root.locked
        WlSessionLockSurface {
            color: Theme.background
            SkyCanvas { anchors.fill: parent }
            LockFace {
                anchors.fill: parent
                user: Quickshell.env("USER") ?? ""
                poll: root.poll; niri: root.niri
                busy: root.busy
                failed: root.failed
                failText: root.lockout
                fingerOn: root.fingerOn
                fingerMissed: root.fingerMissed
                fingerDone: root.fingerMisses >= 3
                onSubmitted: s => root.submit(s)
            }
        }
    }
}
