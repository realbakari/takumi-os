// Approvals: when an app or a command needs your password to change the system, the Core asks for it.
// Two sources. An app asks through polkit; this session's polkit agent is the shell itself. A command run
// with `sudo -A` asks through takumi approve askpass, which hands the shell a FIFO to write the answer to.
// See docs/approvals.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

QtObject {
    id: approvals
    property PolkitAgent agent: PolkitAgent { path: "/org/takumi/PolkitAgent" }
    readonly property var flow: agent.flow

    property string askFifo: ""            // a waiting takumi approve askpass
    property string askWhy: ""
    property double lastAnswer: 0          // sudo asks again after a wrong password; a quick second ask means that
    property bool askFailed: false

    readonly property string kind: askFifo !== "" ? "askpass" : (agent.isActive && flow ? "polkit" : "")
    readonly property bool active: kind !== ""
    readonly property bool failed: kind === "polkit" ? !!flow.failed : askFailed
    readonly property bool busy: kind === "polkit" && !flow.isResponseRequired && !flow.isCompleted
    readonly property bool echo: kind === "polkit" && !!flow.responseVisible
    readonly property string title: kind === "askpass" ? (askWhy || "Your password, to change the system") : kind === "polkit" ? titleFor(flow.actionId) : ""
    readonly property string detail: kind === "polkit" && titleFor(flow.actionId) === "Your password is needed" ? plain(flow.message) : ""

    // What the system is asking for, in words, by polkit action.
    readonly property var titles: [
        ["org.freedesktop.bolt.", "Allowing a dock needs your password"],
        ["org.freedesktop.udisks2.modify-device", "Erasing a drive needs your password"],
        ["org.freedesktop.udisks2.", "Opening a disk needs your password"],
        ["org.freedesktop.NetworkManager.", "Changing the network needs your password"],
        ["org.freedesktop.Flatpak.", "Installing an app needs your password"],
        ["org.freedesktop.packagekit.", "Installing software needs your password"],
        ["org.freedesktop.login1.", "Shutting down needs your password"],
        ["org.freedesktop.timedate1.", "Changing the time needs your password"],
        ["org.freedesktop.hostname1.", "Renaming the computer needs your password"],
        ["org.freedesktop.locale1.set-keyboard", "Changing the keyboard needs your password"],
        ["org.freedesktop.locale1.", "Changing the language needs your password"],
        ["org.freedesktop.systemd1.", "Changing a system service needs your password"],
        ["org.opensuse.cupspkhelper.", "Changing a printer needs your password"],
        ["org.freedesktop.fwupd.", "Updating firmware needs your password"],
        ["org.freedesktop.UPower.PowerProfiles.", "Changing the power mode needs your password"],
        ["org.freedesktop.accounts.", "Changing an account needs your password"]
    ]
    function titleFor(id) {
        const hit = titles.find(t => String(id ?? "").startsWith(t[0]));
        return hit ? hit[1] : "Your password is needed";
    }
    function plain(m) {
        return String(m ?? "").replace(/[`']/g, "").replace(/^Authentication is (needed|required) to /, "To ")
            .replace(/ as the super ?user\.?$/, " with administrator rights").trim();
    }

    function submit(secret) {
        if (kind === "askpass") { answer(secret); return; }
        if (kind === "polkit" && flow.isResponseRequired) flow.submit(secret);
    }
    function cancel() {
        if (kind === "askpass") { answer(""); return; }
        if (kind === "polkit") flow.cancelAuthenticationRequest();
    }
    function ask(fifo, why) {
        askFailed = Date.now() - lastAnswer < 20000;
        askWhy = why; askFifo = fifo;
    }
    // The answer goes to the FIFO through cat's stdin, never as an argument.
    function answer(text) {
        writer.pending = text;
        writer.command = ["sh", "-c", 'cat > "$1"', "_", askFifo];
        writer.stdinEnabled = true;
        writer.running = true;
        if (text !== "") lastAnswer = Date.now();
        askFifo = "";
    }
    property Process writer: Process {
        property string pending: ""
        onStarted: { writer.write(writer.pending + "\n"); writer.pending = ""; writer.stdinEnabled = false; }
    }
}
