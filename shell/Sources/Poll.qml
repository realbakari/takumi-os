// Battery, volume, network and the modes you turned on (do not disturb, staying awake, the night light),
// read on an interval. One process, never overlapping. When the network
// starts asking for a sign-in page (a hotel, a café), the page opens once (takumi wifi signin --auto).
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: poll
    property int battery: -1          // -1: no battery
    property bool charging: false
    property int volume: -1
    property bool muted: false
    property bool online: true
    property string link: "none"      // wifi, wired or none
    property int signal: 0            // the Wi-Fi network in use, 0-100
    property string connectivity: "unknown"   // full, portal, limited, none or unknown
    property bool micInUse: false     // an app is recording the microphone
    property bool cameraInUse: false  // an app takes video through PipeWire
    // Modes you turned on that change how the computer behaves: each shows a mark in the Core at rest.
    property bool dnd: false          // ~/.local/state/takumi/dnd (takumi switch dnd)
    property bool awake: false        // takumi power awake: no lock, no sleep
    property bool nightLight: false   // the night light's wlsunset is running
    property real recordingSince: 0   // takumi screen record: when it started (epoch seconds), 0 when not
    property bool micMuted: false     // the microphone is muted (takumi audio mic)
    property string vpn: ""           // the VPN your internet goes through, by name (takumi vpn state)
    property bool vpnConnecting: false
    property int updates: 0           // updates waiting (takumi update check)
    property bool updateReady: false  // a new system is prepared: restart to use it
    property string driveOpen: ""     // a USB drive or card that is open (takumi drive)
    property bool dictating: false    // takumi voice is listening ($XDG_RUNTIME_DIR/takumi-voice)
    property real timerAt: 0          // the next running timer rings then (epoch seconds), 0 when none (reminders.tsv)
    property int remote: 0            // takumi screen remote: 0 off, 1 on, 2 someone is connected
    readonly property bool recording: recordingSince > 0
    readonly property int bars: signal >= 67 ? 3 : signal >= 34 ? 2 : 1
    // Connected, but a sign-in page or a broken network stands in the way: the mark takes the accent.
    readonly property bool attention: link !== "none" && ["portal", "limited", "none"].includes(connectivity)
    property bool active: true

    property Process proc: Process {
        command: ["sh", "-c",
            "b=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); " +
            "v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "n=$(nmcli -t -f STATE,CONNECTIVITY general 2>/dev/null); " +
            "d=$(nmcli -t -f TYPE,STATE device 2>/dev/null); " +
            "case \"$d\" in *wifi:connected*) l=wifi ;; *ethernet:connected*) l=wired ;; *) l=none ;; esac; " +
            "g=; [ \"$l\" = wifi ] && g=$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | sed -n 's/^\\*://p' | head -1); " +
            "p=$(takumi audio state --marks 2>/dev/null); " +
            "r=${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}; m=no; [ -e \"$HOME/.local/state/takumi/dnd\" ] && m=yes; " +
            "a=no; read -r ap _ 2>/dev/null < \"$r/takumi-awake\" && kill -0 \"$ap\" 2>/dev/null && a=yes; " +
            "t=no; tp=$(cat \"$r/nightlight.pid\" 2>/dev/null) && kill -0 \"$tp\" 2>/dev/null && t=yes; " +
            "k=0; read -r kp ks _ 2>/dev/null < \"$r/takumi-recording\" && kill -0 \"$kp\" 2>/dev/null && k=$ks; " +
            "w=$(takumi vpn state 2>/dev/null | head -n 1); " +
            "u=$(jq -r '\"\\(.count // 0) \\(.ready // false)\"' \"$HOME/.local/state/takumi/updates.json\" 2>/dev/null); " +
            "o=$(head -n 1 \"$r/takumi-drives-open\" 2>/dev/null | tr -d '|'); " +
            "vo=no; read -r vp _ 2>/dev/null < \"$r/takumi-voice\" && kill -0 \"$vp\" 2>/dev/null && vo=yes; " +
            "ti=$(awk -F '\\t' -v now=\"$(date +%s)\" '$2 == \"timer\" && $3 > now && (m == \"\" || $3 < m) { m = $3 } END { print m + 0 }' \"$HOME/.local/state/takumi/reminders.tsv\" 2>/dev/null); " +
            "re=0; read -r rp _ 2>/dev/null < \"$r/takumi-remote\" && kill -0 \"$rp\" 2>/dev/null && { re=1; c=$(wayvncctl -S \"$r/takumi-remote.d/ctl\" -j client-list 2>/dev/null | jq 'if type == \"array\" then length else (.clients // [] | length) end' 2>/dev/null); [ \"${c:-0}\" -gt 0 ] 2>/dev/null && re=2; }; " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s %s %s %s|%s|%s|%s|%s %s %s\\n' \"${b:--1}\" \"${s:-}\" \"${v:-}\" \"${n:-connected:unknown}\" \"$l\" \"${g:-0}\" \"${p:-no no no}\" \"$m\" \"$a\" \"$t\" \"$k\" \"$w\" \"${u:-0 false}\" \"$o\" \"$vo\" \"${ti:-0}\" \"$re\""]
        stdout: SplitParser {
            onRead: line => {
                const [b, s, v, n, l, g, p, modes, w, u, o, x] = line.split("|");
                const more = (x ?? "no 0 0").trim().split(" ");
                poll.dictating = more[0] === "yes"; poll.timerAt = Number(more[1]) || 0; poll.remote = Number(more[2]) || 0;
                const marks = (p ?? "no no no").split(" ");
                poll.micMuted = marks[2] === "yes";
                const vw = (w ?? "").trim(), sp = vw.indexOf(" ");
                poll.vpn = sp > 0 ? vw.slice(sp + 1) : ""; poll.vpnConnecting = vw.startsWith("connecting");
                const up = (u ?? "0 false").trim().split(" ");
                poll.updates = Number(up[0]) || 0; poll.updateReady = up[1] === "true";
                poll.driveOpen = (o ?? "").trim();
                const on = (modes ?? "no no no 0").split(" ");
                poll.dnd = on[0] === "yes"; poll.awake = on[1] === "yes"; poll.nightLight = on[2] === "yes";
                poll.recordingSince = Number(on[3]) || 0;
                poll.micInUse = marks[0] === "yes"; poll.cameraInUse = marks[1] === "yes";
                poll.battery = Number(b); poll.charging = s === "Charging";
                const m = (v ?? "").match(/Volume:\s*([\d.]+)(.*MUTED)?/);
                poll.volume = m ? Math.round(Number(m[1]) * 100) : -1;
                poll.muted = !!(m && m[2]);
                const net = (n ?? "").split(":"), was = poll.connectivity;
                poll.online = (net[0] ?? "").startsWith("connected");
                poll.connectivity = net[1] || "unknown";
                poll.link = l || "none";
                poll.signal = Number(g) || 0;
                if (poll.connectivity === "portal" && was !== "portal") Quickshell.execDetached(["takumi", "wifi", "signin", "--auto"]);
            }
        }
    }
    property Timer timer: Timer {
        interval: 10000; running: poll.active; repeat: true; triggeredOnStart: true
        onTriggered: poll.refresh()
    }
    function refresh() { if (!proc.running) proc.running = true; }
}
