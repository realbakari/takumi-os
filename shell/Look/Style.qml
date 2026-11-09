pragma Singleton
// Every size, alpha and duration in the shell. Nothing else holds a pixel number. See docs/shell.md.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: style

    // Base type size. ~/.config/takumi/shell.toml: [ui] font_size = 13
    property real fontBase: 13
    readonly property real fontScale: fontBase / 13
    // Sizes scale with the font, so a larger text size gives a roomier shell, not a cramped one.
    function space(px) { return Math.max(1, Math.round(px * fontScale)); }
    function spaceReal(px) { return px * fontScale; }

    // Type. One family for the interface, one for data and code. The sizes follow a ramp (caption 12, body
    // 14, a row's title 15, the field 18, a heading 20, a title 28), never under 12 and never bold: weight 600
    // carries emphasis, in sentence case, as Windows' type ramp does for legibility
    // (https://learn.microsoft.com/windows/apps/design/signature-experiences/typography).
    property string uiFamily: "Inter"            // shell.toml font_ui (takumi font set ui)
    property string monoFamily: "JetBrains Mono" // shell.toml font_mono
    readonly property string cjkFamily:  "Noto Sans CJK JP"   // the emblem's one glyph
    readonly property int micro:    space(12)     // small labels: kinds, sections, keys
    readonly property int caption:  space(12)
    readonly property int body:     space(14)
    readonly property int subtitle: space(15)     // a row's title
    readonly property int title:    space(18)     // what you type into the Palette
    readonly property int heading:  space(20)     // a surface's name: Quick settings, a page of setup
    readonly property int display:  space(28)
    readonly property real microTracking: 0.01   // em, for small labels
    readonly property real displayTracking: -0.055 // em, for the lock clock

    // Geometry.
    readonly property int gap:            space(10)   // niri's layout gap; the Core floats by this much
    readonly property int hairline:       1
    readonly property int coreHeight:     space(46)   // the Core at rest: a capsule, its radius half of this
    readonly property int coreRadius:     space(23)
    readonly property int coreOpenRadius: space(22)
    readonly property int coreOpenWidth:  space(640)
    readonly property int coreOpenMin:    space(200)
    readonly property int coreOpenMax:    space(500)
    readonly property int corePadLeft:    space(10)   // the emblem sits as far from the edge as from top and bottom
    readonly property int corePadRight:   space(18)
    readonly property int faceSpacing:    space(16)
    readonly property int field:          space(52)
    readonly property int fieldRadius:    space(13)
    readonly property int planRow:        space(36)
    readonly property int rowHeight:      space(44)
    readonly property int rowHeightCompact: space(38) // a row while browsing: its title alone
    readonly property int rowGap:         space(2)
    readonly property int sectionHeight:  space(26)   // a group's name over its rows in the Palette
    readonly property int rowRadius:      space(11)
    readonly property int iconSlot:       space(30)
    readonly property int appCell:        space(106)   // an app tile on the empty Palette and in the grid of every app
    readonly property int appIcon:        space(44)
    readonly property int appColumns:     6
    readonly property int previewSlotWidth: space(50)
    readonly property int slotRadius:     space(8)
    readonly property int icon:           space(18)
    readonly property int iconSmall:      space(15)
    readonly property int emblemSmall:    space(16)
    readonly property int emblemCore:     space(26)   // in the Core at rest
    // The Core at rest: its type, icons and the widest a window's title or a song may run.
    readonly property int restText:       space(14)
    readonly property int restTime:       space(15)
    readonly property int restSmall:      space(12)
    readonly property int restIcon:       space(18)
    readonly property int restAppIcon:    space(20)
    readonly property int restSlot:       space(22)   // a workspace's number
    readonly property int restTitle:      space(300)
    readonly property int restMedia:      space(240)
    readonly property int emblemLock:     space(34)
    readonly property real emblemRadius:  0.28   // of its size
    readonly property real emblemGlyph:   0.74   // the glyph's height as a share of the tile
    readonly property int mapUnit:        space(56)   // a full-width column on the strip minimap
    readonly property int lockField:      space(240)
    readonly property int cardHeight:     space(196)  // a card in the open Core (sharing Wi-Fi)
    readonly property int approvalWidth:  space(520)  // the Core asking for your password
    readonly property int qrTile:         space(168)
    readonly property int qrRadius:       space(14)
    // Quick settings and Today, the Core's other two open shapes, and the word above the Core at rest.
    readonly property int quickWidth:     space(420)
    readonly property int todayWidth:     space(372)
    readonly property int tileHeight:     space(58)   // a switch in Quick settings
    readonly property int tileRadius:     space(16)
    readonly property int tileGap:        space(8)
    readonly property int iconDisc:       space(34)   // the round field a switch's icon sits in
    readonly property int levelHeight:    space(34)   // the sound and brightness levels
    readonly property int dayCell:        space(32)   // a day in Today's month
    readonly property int peekHeight:     space(28)
    readonly property int coreSurface:    space(560)  // the Core's surface: room for its tallest open shape
    // The setup disc's screen (shell/setup.qml): the glass the questions sit in, its type, its lists.
    readonly property int setupWidth:     space(600)
    readonly property int setupPad:       space(36)
    readonly property int setupRadius:    space(26)
    readonly property int setupTitle:     space(30)
    readonly property int setupList:      space(276)  // six rows of choices
    readonly property int setupButton:    space(44)
    readonly property int setupCode:      space(28)   // the recovery code's digits
    readonly property int setupBar:       space(6)    // the install's progress line
    readonly property int setupDot:       space(6)    // the questions, as dots under the glass

    // Alphas: the foreground over the surface. One set serves light and dark.
    readonly property real coreFill:      0.94    // at rest, over the sky
    readonly property real coreFillOpen:  0.985   // open over windows: their edges must not show through
    // With a GPU, niri blurs what is behind the Core (ext-background-effect, through Quickshell's
    // BackgroundEffect), so the body can be glass: the blur keeps words readable over any window.
    readonly property real glassFill:     0.72
    readonly property real glassFillOpen: 0.84
    readonly property real fillField:     0.06
    readonly property real fillHover:     0.05
    readonly property real fillSelected:  0.11    // of the accent
    readonly property real fillCurrent:   0.09    // the Palette's current row, of the foreground (its rail is the accent)
    readonly property real fillSlotCurrent: 0.14  // the selected row's icon slot, of the accent
    readonly property real fillPressed:   0.14
    readonly property real lineHair:      0.11
    readonly property real lineHighlight: 0.07
    // Text over the surface: secondary, the small labels, hints. High enough to pass 4.5:1 on the surface.
    readonly property real textDim:       0.72
    readonly property real textMicro:     0.58
    readonly property real textFaint:     0.50
    readonly property real scrim:         0.30
    readonly property real shadow:        0.45
    readonly property real signalOff:     0.22   // the unlit arcs of the Wi-Fi mark
    // The Core's light: its rim (top, the rest, the bottom; lit is of the accent), the sheen, the aura.
    readonly property real rimTop:        0.24
    readonly property real rimMid:        0.09
    readonly property real rimLow:        0.05
    readonly property real rimLit:        0.60
    readonly property real sheen:         0.05
    readonly property real auraAlpha:     0.26
    readonly property real skyTint:       0.07   // the accent along the top of the Core, the sky showing through
    readonly property real lockGlass:     0.55   // the lock's field over the sky
    readonly property real lockGhost:     0.07   // the outline of the great 匠 behind the Lock's clock
    readonly property real lockCorner:    0.30   // the marks at the Lock's corners
    readonly property real fillTile:      0.055  // a switch that is off
    readonly property real fillTileOn:    0.17   // a switch that is on, of the accent
    readonly property real shade:         0.09   // the innermost ring of the shadow drawn without a GPU

    // The boot splash (default/plymouth/takumi, drawn by install/plymouth/render.qml): the login screen's
    // first picture repeats it, so these stay the splash's colours whatever the theme.
    readonly property color bootNight:  "#0b0f14"
    readonly property color bootLine:   "#1b2530"
    readonly property color bootAccent: "#5ad7ff"

    // Motion: fast and direct (Windows' motion guidance,
    // https://learn.microsoft.com/windows/apps/design/signature-experiences/motion). Things that arrive
    // decelerate in 167 ms (easeEnter), things already on screen travel point to point in 167 to 333 ms
    // (easeMove), opacity alone takes 83 ms, and leaving is never slower than arriving. The Core's change of
    // shape keeps a little spring: the one deliberate flourish.
    property bool reduceMotion: false
    function duration(ms) { return reduceMotion ? 0 : ms; }
    // A VM without 3D draws every frame on the CPU (takumi session start and takumi greeter say so): then
    // nothing moves for long (no twinkling, breathing or sweeping) and no glow is drawn; the short motions
    // stay. See docs/vm.md.
    readonly property bool softwareDrawing: Quickshell.env("TAKUMI_DRAWING") === "software"
    readonly property bool continuousMotion: !reduceMotion && !softwareDrawing
    readonly property bool glow: !softwareDrawing
    readonly property int enter:      duration(167)
    readonly property int exit:       duration(167)
    readonly property int fade:       duration(83)
    readonly property int quick:      duration(83)    // hover and press
    readonly property int morph:      duration(333)
    readonly property int slide:      duration(333)
    readonly property int retint:     duration(1500)
    readonly property int breathe:    760          // one half of a busy row's breath
    readonly property int sweep:      1100         // the field's progress line, one pass
    readonly property int answerGuard: 600          // a new question ignores Enter this long (not shortened by reduced motion)
    readonly property int glide:      duration(167) // the selection moving from row to row
    readonly property int arrive:     duration(820) // the splash's tile rising onto the login screen
    readonly property int stagger:    18           // between rows appearing as the Core opens
    readonly property int noticeHold: 1800
    readonly property int peekDwell:  450          // resting on a mark this long brings its word
    readonly property real press:     0.975
    readonly property var easeEnter:  [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var easeMove:   [0.55, 0.55, 0.0, 1.0, 1.0, 1.0]
    readonly property var easeExit:   [1.0, 0.0, 1.0, 1.0, 1.0, 1.0]
    readonly property var easeOut:    easeEnter
    readonly property var spring:     [0.3, 1.25, 0.4, 1.0, 1.0, 1.0]

    // Intent shows its plan while you type. Off when the endpoint is hosted and you would rather not pay per keystroke.
    property bool intentPreview: true

    // ~/.config/takumi/shell.toml, watched.
    property FileView config: FileView {
        path: Quickshell.env("HOME") + "/.config/takumi/shell.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: style.apply(text())
    }
    function apply(text) {
        try {
            const fs = text.match(/^font_size\s*=\s*([\d.]+)/m);
            if (fs) fontBase = Math.max(10, Math.min(20, Number(fs[1])));
            const rm = text.match(/^reduce_motion\s*=\s*(true|false)/m);
            if (rm) reduceMotion = rm[1] === "true";
            const fu = text.match(/^font_ui\s*=\s*"([^"]+)"/m); uiFamily = fu ? fu[1] : "Inter";
            const fm = text.match(/^font_mono\s*=\s*"([^"]+)"/m); monoFamily = fm ? fm[1] : "JetBrains Mono";
            const ip = text.match(/^intent_preview\s*=\s*(true|false)/m);
            if (ip) intentPreview = ip[1] === "true";
        } catch (e) { console.warn("shell.toml:", e); }
    }
}
