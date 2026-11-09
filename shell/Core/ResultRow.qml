// One result: an accent rail when selected, an icon slot (app icon, stroke icon, signal bars or theme
// swatch), the title with the match lit, a subtitle, then "asks" for rows above risk tier 0, the kind, and
// Alt+n while Alt is held. A row can carry a tone: "busy" (the rail breathes, the subtitle is the accent: joining) or
// "error" (the subtitle is red: that password did not work).
import QtQuick
import Quickshell
import "../Look"
import "../Parts"

Pressable {
    id: row
    required property var modelData
    required property int index
    property bool current: false
    property bool armed: false
    property bool entering: false            // the Core just opened: come in after the rows below
    property bool showKey: false             // Alt is held: show this row's Alt+number
    opacity: 1
    transform: Translate { id: rise }
    Component.onCompleted: if (entering && !Style.reduceMotion && index < 9) { opacity = 0; rise.y = Style.space(8); appear.start(); }
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: row.index * Style.stagger }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 1; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
            NumberAnimation { target: rise; property: "y"; to: 0; duration: Style.enter * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
        }
    }
    property string query: ""
    // A conversation's row: its question or note wraps onto up to four lines rather than being cut short.
    property bool wrap: false
    property int ordinal: index            // its place among the rows that are not names, for Alt+n
    // Browsing (nothing typed): one line, the title alone. A row's words under it come with a search, where
    // they tell results apart, or when they say something about now (press again, working, failed).
    property bool compact: false
    readonly property bool detailed: !compact || armed || busy || modelData.tone === "error"
    // A group's name ("Best match", "Apps"): a small label over its rows, never selected or run.
    readonly property bool isName: !!modelData.header
    signal activated()

    height: isName ? Style.sectionHeight : wrap ? Math.max(Style.rowHeight, words.implicitHeight + Style.space(18)) : detailed ? Style.rowHeight : Style.rowHeightCompact
    enabled: !isName
    accessibleName: [modelData.title, modelData.subtitle].filter(s => s).join(". ")
    selected: false                          // the list's own highlight glides under the current row
    color: hovered && !current && !isName ? Theme.tint(Style.fillHover) : "transparent"
    onClicked: activated()

    readonly property string appPath: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : ""
    readonly property string previewPath: modelData.preview ?? ""
    readonly property bool busy: modelData.tone === "busy"
    readonly property bool hasBars: modelData.bars !== undefined
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    readonly property string titleMarkup: {
        const t = modelData.title ?? "", q = query.trim();
        if (modelData.kind === "Intent") return "“" + esc(t) + "”";
        const i = q ? t.toLowerCase().indexOf(q.toLowerCase()) : -1;
        if (i < 0) return esc(t);
        return esc(t.slice(0, i)) + "<font color=\"" + Theme.hex(Theme.accent) + "\">" + esc(t.slice(i, i + q.length)) + "</font>" + esc(t.slice(i + q.length));
    }

    Label {
        visible: row.isName
        anchors { left: parent.left; leftMargin: Style.space(14); bottom: parent.bottom; bottomMargin: Style.space(4) }
        micro: true
        text: row.modelData.title ?? ""
    }

    Rectangle {   // working on it: the rail breathes
        x: 0; y: Style.space(12); width: 2; height: parent.height - Style.space(24); radius: 1
        color: Theme.accent
        visible: row.busy
        SequentialAnimation on opacity {
            running: row.busy && Style.continuousMotion; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: Style.breathe; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.2; to: 1; duration: Style.breathe; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        id: slot
        visible: !row.isName
        x: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        width: row.previewPath ? Style.previewSlotWidth : Style.iconSlot; height: Style.iconSlot; radius: Style.slotRadius
        // Glyphs stand bare, in the text's colour (the accent on the current row); only a picture gets a frame.
        color: row.previewPath ? Theme.background : "transparent"
        border.width: row.previewPath ? Style.hairline : 0
        border.color: row.current ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.lineHair)
        Image {
            visible: row.previewPath !== ""
            anchors.fill: parent
            anchors.margins: Style.hairline
            source: row.previewPath ? "file://" + row.previewPath : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Style.previewSlotWidth * 2, Style.iconSlot * 2)
            asynchronous: true
        }
        Image {
            visible: row.appPath !== ""
            anchors.centerIn: parent
            width: Style.space(26); height: width
            source: row.appPath
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
        }
        Label {
            visible: !!row.modelData.char
            anchors.centerIn: parent
            text: row.modelData.char ?? ""
            font.pixelSize: Style.space(20)
            elide: Text.ElideNone
        }
        Icon {
            visible: row.appPath === "" && !row.modelData.swatch && !row.hasBars && !row.modelData.char && row.previewPath === ""
            anchors.centerIn: parent
            name: row.modelData.icon ?? "cmd"
            color: row.current ? Theme.accent : Theme.tint(0.72)
        }
        SignalIcon {
            visible: row.hasBars
            anchors.centerIn: parent
            bars: row.modelData.bars ?? 3
            color: row.current ? Theme.accent : Theme.tint(0.72)
        }
        Row {
            visible: !!row.modelData.swatch && row.previewPath === ""
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: row.modelData.swatch ?? []
                delegate: Rectangle { required property var modelData; width: Style.space(5); height: Style.space(14); radius: 1.5; color: modelData }
            }
        }
    }

    Column {
        id: words
        visible: !row.isName
        anchors { left: slot.right; leftMargin: Style.space(12); right: trailing.left; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
        Label { width: parent.width; text: row.titleMarkup; textFormat: Text.StyledText; font.pixelSize: Style.subtitle }
        Label {
            width: parent.width
            // Only the first letter goes lower case: "shut down", "get LocalSend".
            readonly property string what: String(row.modelData.title ?? "")
            text: row.armed ? "Press Enter again to " + what.charAt(0).toLowerCase() + what.slice(1) : (row.modelData.subtitle ?? "")
            color: row.armed || row.busy ? Theme.accent : row.modelData.tone === "error" ? Theme.red : Theme.withAlpha(Theme.foreground, 0.55)
            font.pixelSize: row.wrap ? Style.body : Style.caption; visible: text !== "" && (row.detailed || row.wrap)
            font.family: row.modelData.font ?? Style.uiFamily
            wrapMode: row.wrap ? Text.WordWrap : Text.NoWrap
            maximumLineCount: row.wrap ? 4 : 1
        }
    }

    Row {
        id: trailing
        visible: !row.isName
        anchors { right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
        spacing: Style.space(10)
        // A command that asks before it changes anything says so in a word, not a badge.
        Label { anchors.verticalCenter: parent.verticalCenter; micro: true; visible: (row.modelData.risk ?? 0) > 0; text: "Asks first" }
        Label { anchors.verticalCenter: parent.verticalCenter; micro: true; text: row.modelData.kind ?? ""; visible: row.modelData.kindShown ?? true }
        Rectangle {
            visible: row.showKey && row.ordinal < 9
            anchors.verticalCenter: parent.verticalCenter
            width: keyLabel.implicitWidth + Style.space(10); height: Style.space(18); radius: Style.space(5)
            color: "transparent"; border.width: 1; border.color: Theme.tint(0.16)
            Label { id: keyLabel; anchors.centerIn: parent; text: "Alt " + (row.ordinal + 1); font.pixelSize: Style.caption; dim: Style.textDim }
        }
    }
}
