// What the setup screen knows and does: the computer's facts and guesses, the languages, keyboards, places
// and disks to choose from, the answers so far, and the install itself. The takumi-setup-* commands do the
// work; this holds the state. At a first start (TAKUMI_SETUP_MODE=owner, takumi setup start --owner) the same
// screen asks a computer's owner and gives it to them instead of installing (takumi setup owner). See
// docs/setup.md.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: setup
    // language, keyboard, place, you, disk: the questions; then installing, code, done (or failed). A first
    // start asks all but the disk.
    readonly property bool firstStart: Quickshell.env("TAKUMI_SETUP_MODE") === "owner"
    // At a first start, whether the disk is encrypted (takumi setup start); the setup disc always encrypts.
    readonly property bool encrypted: !firstStart || Quickshell.env("TAKUMI_SETUP_ENCRYPTED") !== "0"
    property string page: "language"
    readonly property var questions: firstStart ? ["language", "keyboard", "place", "you"] : ["language", "keyboard", "place", "you", "disk"]

    property var facts: ({})
    property var languages: []
    property var keyboards: []
    property var zones: []
    property var disks: []
    property bool disksRead: false

    property string locale: "en_US.UTF-8"
    property string localeName: "English (US)"
    // A keyboard or a place the person chose stays when they choose a language after it.
    property bool keyboardChosen: false
    property bool zoneChosen: false
    property bool forOther: false           // set up for someone else: no account yet, a password for now
    property string layout: "us"
    property string variant: ""
    property string layoutName: "English (US)"
    property string zone: "UTC"
    property string zoneCity: "UTC"
    property var here: ({ time: "", day: "", phase: "night" })
    property string name: ""
    property string disk: ""
    property string mode: "erase"           // or "beside": next to Windows, in the disk's free space
    function pickDisk(path) { disk = path; mode = diskInfo && diskInfo.beside ? "beside" : "erase"; }
    readonly property var diskInfo: disks.find(d => d.path === disk) ?? null
    readonly property string account: accountFor(name)
    readonly property string host: account ? account + "-takumi" : "takumi"

    property string stepText: ""
    property int progress: 0
    property string code: ""
    property var codeRows: []
    property string failure: ""
    property var failureLog: []

    // A person's first name as an account: letters a to z and digits, starting with a letter.
    readonly property var reserved: ["root", "bin", "daemon", "mail", "ftp", "http", "nobody", "dbus", "polkitd", "greeter",
        "live", "git", "avahi", "colord", "cups", "rtkit", "usbmux", "uuidd", "tss", "alpm", "geoclue", "flatpak", "saned", "takumi"]
    function accountFor(n) {
        let s = (n || "").trim().split(/\s+/)[0] || "";
        s = s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
             .replace(/ß/g, "ss").replace(/æ/g, "ae").replace(/œ/g, "oe").replace(/ø/g, "o").replace(/ł/g, "l")
             .replace(/[^a-z0-9]/g, "");
        s = s.replace(/^[0-9]+/, "");
        if (s === "" && (n || "").trim() !== "") s = "me";
        if (reserved.indexOf(s) >= 0 || s.startsWith("systemd")) s = s + "1";
        return s.slice(0, 30);
    }

    function lines(text) { return text.split("\n").filter(l => l.trim() !== "").map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(x => x); }

    Process {
        id: factsProc
        running: true
        command: ["takumi", "setup", "facts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { setup.facts = JSON.parse(this.text); } catch (e) { return; }
                setup.layout = setup.facts.layout || "us";
                setup.variant = setup.facts.variant || "";
                setup.locale = setup.facts.locale || "en_US.UTF-8";
                setup.pickZone(setup.facts.zone || "UTC", true);
                setup.nameLayout();
                setup.nameLocale();
            }
        }
    }
    Process {
        running: true
        command: ["takumi", "language", "list", "--json"]
        stdout: StdioCollector { onStreamFinished: { setup.languages = setup.lines(this.text); setup.nameLocale(); } }
    }
    function nameLocale() {
        const l = languages.find(l => l.code === locale);
        if (l) localeName = l.name;
    }
    // A language says where its people mostly are: the keyboard and the place start there, unless the
    // person already chose them (takumi setup facts --for).
    function pickLanguage(l) {
        locale = l.code; localeName = l.name;
        const cc = (l.code.split("_")[1] || "").slice(0, 2);
        if (cc.length !== 2 || (keyboardChosen && zoneChosen)) return;
        guessProc.command = ["takumi", "setup", "facts", "--for", cc];
        guessProc.running = true;
    }
    Process {
        id: guessProc
        stdout: StdioCollector {
            onStreamFinished: {
                let g; try { g = JSON.parse(this.text); } catch (e) { return; }
                if (!setup.keyboardChosen && g.layout && (g.layout !== setup.layout || g.variant !== setup.variant)) {
                    const k = setup.keyboards.find(k => k.layout === g.layout && k.variant === (g.variant || ""));
                    if (k) { setup.layout = k.layout; setup.variant = k.variant; setup.layoutName = k.name; applyKeyboard.restart(); }
                }
                if (!setup.zoneChosen && g.zone) setup.pickZone(g.zone, true);
            }
        }
    }
    Process {
        running: true
        command: ["takumi", "setup", "keyboards"]
        stdout: StdioCollector { onStreamFinished: { setup.keyboards = setup.lines(this.text); setup.nameLayout(); } }
    }
    Process {
        running: true
        command: ["takumi", "setup", "zones"]
        stdout: StdioCollector { onStreamFinished: { setup.zones = setup.lines(this.text); setup.nameZone(); } }
    }
    function nameLayout() {
        const k = keyboards.find(k => k.layout === layout && k.variant === variant);
        if (k) layoutName = k.name;
    }
    function nameZone() {
        const z = zones.find(z => z.zone === zone);
        zoneCity = z ? z.city : zone.split("/").pop().replace(/_/g, " ");
    }

    // The keyboard changes at once, a moment after the choice settles.
    function pickKeyboard(k) {
        layout = k.layout; variant = k.variant; layoutName = k.name; keyboardChosen = true;
        applyKeyboard.restart();
    }
    Timer { id: applyKeyboard; interval: 180; onTriggered: { kbProc.command = ["takumi", "setup", "keyboard", setup.layout].concat(setup.variant ? [setup.variant] : []); kbProc.running = true; } }
    Process { id: kbProc }

    // The place: its time now, and the sky turns to its part of the day.
    function pickZone(z, guessed) {
        if (!guessed) zoneChosen = true;
        zone = z; nameZone(); hereProc.command = ["takumi", "setup", "zones", "--at", z]; hereProc.running = true;
    }
    // Only when asked: ipinfo.io sees this computer's internet address (takumi setup zones --guess).
    property string lookup: ""              // "", "asking", "found" or "failed"
    function guessZone() { lookup = "asking"; onlineProc.running = true; }
    Process {
        id: onlineProc
        command: ["takumi", "setup", "zones", "--guess"]
        stdout: StdioCollector {
            onStreamFinished: {
                let g = null; try { g = JSON.parse(this.text); } catch (e) {}
                if (g && g.zone) { setup.pickZone(g.zone); setup.lookup = "found"; } else setup.lookup = "failed";
            }
        }
        onExited: (code, status) => { if (code !== 0) setup.lookup = "failed"; }
    }
    Process {
        id: hereProc
        stdout: StdioCollector { onStreamFinished: { try { setup.here = JSON.parse(this.text); } catch (e) {} } }
    }
    Timer { interval: 30000; repeat: true; running: setup.page === "place" || setup.page === "you"; onTriggered: setup.pickZone(setup.zone, !setup.zoneChosen) }

    // Disks come and go (a USB stick): read them again while the question is open.
    Process {
        id: disksProc
        command: ["takumi", "setup", "disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                setup.disks = setup.lines(this.text);
                setup.disksRead = true;
                const usable = setup.disks.filter(d => d.ok);
                if (!setup.disks.find(d => d.path === setup.disk && d.ok))
                    setup.pickDisk(usable.length ? (usable.find(d => d.kind !== "usb") ?? usable[0]).path : "");
                else if (setup.mode === "beside" && !(setup.diskInfo && setup.diskInfo.beside)) setup.mode = "erase";
            }
        }
    }
    Timer { interval: 3000; repeat: true; triggeredOnStart: true; running: setup.page === "disk"; onTriggered: if (!disksProc.running) disksProc.running = true }

    // Installing: the answers on one line and the password on the next, written to the installer's input,
    // never put on its command line.
    property string pending: ""
    function install(password) {
        const answers = { disk: disk, mode: mode, layout: layout, variant: variant, zone: zone, locale: locale, name: name.trim(), user: account, host: host,
                          owner: forOther ? "later" : "", software: Quickshell.env("TAKUMI_DRAWING") === "software" };
        run(["sudo", "-n", "/usr/lib/takumi/commands/setup/install"], answers, password);
    }
    // A first start: the account, the computer's name, keyboard, place and language, and the owner's password
    // on the disk (takumi setup owner apply, as root).
    function claim(password) {
        const answers = { name: name.trim(), user: account, host: host, layout: layout, variant: variant, zone: zone, locale: locale };
        run(["sudo", "-n", "/usr/lib/takumi/commands/setup/owner", "apply"], answers, password);
    }
    function run(command, answers, password) {
        stepText = "Starting"; progress = 0; failure = ""; failureLog = []; code = ""; codeRows = [];
        pending = JSON.stringify(answers) + "\n" + password + "\n";
        page = "installing";
        installProc.command = command;
        installProc.running = true;
    }
    Process {
        id: installProc
        stdinEnabled: true
        onStarted: { installProc.write(setup.pending); setup.pending = ""; }
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" "), word = sp < 0 ? line : line.slice(0, sp), rest = sp < 0 ? "" : line.slice(sp + 1);
                if (word === "step") setup.stepText = rest;
                else if (word === "progress") setup.progress = Number(rest) || setup.progress;
                else if (word === "recovery") setup.code = rest;
                else if (word === "fail") setup.failure = rest;
                else if (word === "done") setup.progress = 100;
            }
        }
        onExited: (code, status) => {
            setup.pending = "";
            // Set up for someone else, or a disk without encryption: no code to keep.
            if (code === 0 && setup.code !== "") { setup.drawCode(); setup.page = "code"; }
            else if (code === 0 && (setup.forOther || setup.firstStart)) setup.page = "ready";
            else {
                if (!setup.failure) setup.failure = setup.stepText || "Starting";
                logProc.running = true;
                setup.page = "failed";
            }
        }
    }
    Process {
        id: logProc
        command: ["tail", "-n", "14", "/run/takumi-setup/install.log"]
        stdout: StdioCollector { onStreamFinished: setup.failureLog = this.text.split("\n").map(l => l.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")).filter(l => l !== "") }
    }

    // The recovery code as a code a phone camera reads: qrencode reads it on its input.
    function drawCode() { qrProc.running = true; }
    Process {
        id: qrProc
        command: ["qrencode", "-t", "ASCII", "-m", "0", "-o", "-"]
        stdinEnabled: true
        onStarted: { qrProc.write(setup.code); qrProc.stdinEnabled = false; }
        stdout: StdioCollector {
            onStreamFinished: setup.codeRows = this.text.split("\n").filter(l => l !== "").map(l => l.replace(/##/g, "1").replace(/  /g, "0"))
        }
        onExited: qrProc.stdinEnabled = true
    }

    function restart() { Quickshell.execDetached(["sudo", "-n", "systemctl", "reboot"]); }
    // A first start ends by ending niri: the login screen follows (takumi-first-start.service).
    function finish() { Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]); }
    function turnOff() { Quickshell.execDetached(["sudo", "-n", "systemctl", "poweroff"]); }
}
