// The painted sky as an item, used by the background (Sky.qml) and the lock screen. A theme's own
// background image, when it ships one, wins. Changes crossfade: the current scene is captured, held on
// top, and faded out once the new sky or wallpaper is ready. Choosing a theme is the one exception: the
// captured scene parts along its horizon, its halves drawing away up and down with the new accent's light
// on their edges, and the new sky is underneath (the opening). Previews and new phases only crossfade.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Look/Sky.js" as SkyPaint

Item {
    id: sky
    readonly property string wallpaperPath: Quickshell.env("TAKUMI_WALLPAPER") || (Quickshell.env("HOME") + "/.local/state/takumi/look/sky")
    readonly property string effectiveTheme: Theme.previewing !== "" ? Theme.previewing : Theme.name
    property var sched: ({ dawn: 330, day: 480, dusk: 1050, night: 1230 })
    property var grab: null             // keeps the captured image alive while it fades
    property bool drawn: false          // the first painting (or the theme's picture) is on screen
    property string committedWallpaper: ""
    property string shownWallpaper: ""
    readonly property string targetWallpaper: Theme.previewing !== ""
        ? (Theme.previewWallpaper !== "" ? ("file://" + Theme.previewWallpaper) : "")
        : committedWallpaper
    property int retintToken: 0
    property string committedName: ""   // the chosen theme the last transition went to
    property string paintedName: ""     // the theme whose sky the canvas last painted
    property bool opening: false        // this transition is a theme being chosen
    property real openAt: 0             // where the captured scene parts: its horizon
    property real gap: 0                // how far each half has drawn away from it
    property bool probeQueued: false
    onVisibleChanged: if (visible && shownWallpaper === "") canvas.requestPaint()

    function minutes(s, fallback) { const m = /^(\d{1,2}):(\d{2})$/.exec(s ?? ""); return m ? Number(m[1]) * 60 + Number(m[2]) : fallback; }

    FileView {
        path: Quickshell.env("TAKUMI_PHASE_FILE") || (Quickshell.env("HOME") + "/.config/takumi/phase.toml")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text(), get = k => (t.match(new RegExp("^" + k + "\\s*=\\s*\"([^\"]*)\"", "m")) || [])[1];
            sky.sched = { dawn: sky.minutes(get("dawn"), 330), day: sky.minutes(get("day"), 480),
                          dusk: sky.minutes(get("dusk"), 1050), night: sky.minutes(get("night"), 1230) };
            if (sky.shownWallpaper === "") canvas.requestPaint();
        }
    }

    // Resolve ~/.local/state/takumi/look/sky (or TAKUMI_WALLPAPER) to the real file path so
    // Image caching works cleanly and removed symlinks fall back to the Sky.
    Process {
        id: probe
        command: ["sh", "-c", 'p=$(readlink -f "$1" 2>/dev/null || true); [ -f "$p" ] && printf "%s" "$p"', "_", sky.wallpaperPath]
        running: true
        property string out: ""
        stdout: SplitParser { onRead: line => probe.out += line }
        onStarted: { probe.out = ""; sky.probeQueued = false; }
        onExited: code => {
            const p = probe.out.trim();
            sky.committedWallpaper = p ? ("file://" + p + (p === sky.wallpaperPath ? ("?r=" + Theme.revision) : "")) : "";
            if (sky.probeQueued) { probe.running = true; return; }
            if (Theme.previewing === "") sky.beginTransition();
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        Image {
            id: wallpaper
            anchors.fill: parent
            source: sky.shownWallpaper
            cache: true
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: sky.shownWallpaper !== "" && status === Image.Ready
            onStatusChanged: {
                if (sky.shownWallpaper === "") return;
                if (status === Image.Ready) {
                    sky.drawn = true;
                    if (previous.visible && !fade.running) sky.reveal();
                } else if (status === Image.Error) {
                    sky.shownWallpaper = "";
                    canvas.requestPaint();
                }
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            visible: !wallpaper.visible
            onPaint: {
                sky.paintedName = sky.effectiveTheme;
                const now = new Date(), m = now.getHours() * 60 + now.getMinutes();
                const follows = SkyPaint.phaseAt(m, sky.sched) === Theme.phase;
                SkyPaint.paint(getContext("2d"), width, height,
                    { accent: Theme.hex(Theme.accent), background: Theme.hex(Theme.background),
                      surface: Theme.hex(Theme.surface), foreground: Theme.hex(Theme.foreground),
                      muted: Theme.hex(Theme.muted), cyan: Theme.hex(Theme.cyan),
                      blue: Theme.hex(Theme.blue), magenta: Theme.hex(Theme.magenta),
                      yellow: Theme.hex(Theme.yellow), green: Theme.hex(Theme.green),
                      red: Theme.hex(Theme.red) },
                    Theme.phase, SkyPaint.arc(Theme.phase, m, sky.sched, follows), sky.effectiveTheme);
            }
            onPainted: {
                sky.drawn = true;
                if (sky.shownWallpaper === "" && previous.visible && !fade.running) sky.reveal();
            }
            onWidthChanged: if (visible) requestPaint()
            onHeightChanged: if (visible) requestPaint()
        }

        // At night, on non-wallpaper dark skies, stars twinkle over the painting.
        Repeater {
            model: canvas.visible && Theme.mode === "dark" && Theme.phase === "night" && Style.continuousMotion
                ? SkyPaint.twinkles(sky.width, sky.height, sky.effectiveTheme) : []
            delegate: Rectangle {
                required property var modelData
                x: modelData.x; y: modelData.y; width: modelData.size; height: width; radius: width / 2
                color: Theme.foreground
                opacity: 0.2
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation { duration: modelData.delay }
                    NumberAnimation { to: 0.9; duration: modelData.period / 2; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.15; duration: modelData.period / 2; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Image { id: previous; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; visible: false }

    // The opening: the captured scene in two halves, parting at openAt by gap each way.
    Item {
        id: parted
        anchors.fill: parent
        visible: false
        Item {
            width: parent.width; height: Math.max(0, sky.openAt - sky.gap)
            clip: true
            Image { width: sky.width; height: sky.height; source: previous.source; fillMode: Image.PreserveAspectCrop }
        }
        Item {
            id: lowerHalf
            y: Math.min(sky.height, sky.openAt + sky.gap)
            width: parent.width; height: Math.max(0, sky.height - y)
            clip: true
            Image { y: -lowerHalf.y; width: sky.width; height: sky.height; source: previous.source; fillMode: Image.PreserveAspectCrop }
        }
        // On each edge, the new accent: a bright line, and its glow falling into the new sky.
        Repeater {
            model: 2
            Item {
                id: edge
                required property int index
                readonly property bool upper: index === 0
                // Never more glow than there is opening: at first a bright slit, then light falling in.
                width: sky.width; height: Math.min(Style.space(110), Math.max(Style.space(2), sky.gap))
                y: upper ? sky.openAt - sky.gap : sky.openAt + sky.gap - height
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accentTint(edge.upper ? 0.26 : 0) }
                        GradientStop { position: 1; color: Theme.accentTint(edge.upper ? 0 : 0.26) }
                    }
                }
                Rectangle {
                    y: edge.upper ? 0 : edge.height - height
                    width: edge.width; height: Style.space(2)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accentTint(0.35) }
                        GradientStop { position: 0.5; color: Qt.lighter(Theme.accent, 1.4) }
                        GradientStop { position: 1; color: Theme.accentTint(0.35) }
                    }
                }
            }
        }
    }
    SequentialAnimation {
        id: part
        PropertyAction { target: sky; property: "gap"; value: 0 }
        NumberAnimation {
            target: sky; property: "gap"; to: Math.max(sky.openAt, sky.height - sky.openAt) + Style.space(110)
            duration: Style.duration(1150); easing.type: Easing.InOutCubic
        }
        ScriptAction { script: { parted.visible = false; previous.source = ""; sky.grab = null; sky.opening = false; } }
    }
    function reveal() {
        if (!opening) { fade.restart(); return; }
        parted.visible = true; previous.visible = false;
        part.restart();
    }
    NumberAnimation {
        id: fade
        target: previous; property: "opacity"; from: 1; to: 0
        duration: Style.retint; easing.type: Easing.InOutQuad
        onFinished: { previous.visible = false; previous.source = ""; sky.grab = null; }
    }

    function beginTransition() {
        const nextUrl = targetWallpaper;
        const tok = ++retintToken;
        const fresh = Theme.previewing === "" && committedName !== "" && Theme.name !== committedName;
        if (Theme.previewing === "") committedName = Theme.name;
        // Choosing a theme changes the palette more than once (rendered, then reloaded): while the opening
        // is under way the later changes only bring the newest scene, under the parting halves.
        if (!fresh && (part.running || parted.visible || (sky.opening && previous.visible))) {
            if (shownWallpaper !== nextUrl) shownWallpaper = nextUrl;
            if (nextUrl === "") canvas.requestPaint();
            return;
        }
        // A newer change while a chosen theme's scene is still being captured keeps it an opening.
        const chosen = fresh || sky.opening;
        sky.opening = chosen;
        if (stage.width <= 0 || Style.retint === 0 || !sky.drawn) {
            sky.opening = false;
            shownWallpaper = nextUrl;
            if (nextUrl === "") canvas.requestPaint();
            return;
        }
        stage.grabToImage(result => {
            if (tok !== sky.retintToken) return;
            sky.grab = result;
            fade.stop(); part.stop(); parted.visible = false;
            // A picture's horizon is not known: most sit near three fifths down.
            sky.openAt = sky.shownWallpaper !== "" ? sky.height * 0.6 : SkyPaint.horizon(sky.width, sky.height, sky.paintedName);
            previous.source = result.url;
            previous.opacity = 1;
            previous.visible = true;
            sky.shownWallpaper = nextUrl;
            if (nextUrl === "") canvas.requestPaint();
            else if (wallpaper.status === Image.Ready) sky.reveal();
        });
    }

    function retint() {
        if (Theme.previewing !== "") beginTransition();
        else if (probe.running) probeQueued = true;
        else probe.running = true;
    }

    Connections { target: Theme; function onRevisionChanged() { debounce.restart(); } }
    Timer { id: debounce; interval: 40; onTriggered: sky.retint() }
    // The disc moves through the day; repaint every five minutes, without a crossfade.
    Timer { interval: 300000; running: true; repeat: true; onTriggered: if (sky.shownWallpaper === "") canvas.requestPaint() }
}
