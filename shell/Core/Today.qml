// Today: the Core grown into the date. The day, with the weather when it is on; clocks for other cities; the
// month with today in the accent (the arrows, Page Up and Page Down, or the wheel go to the months around it,
// and Home comes back); what is coming, timers counting down and reminders; and what your apps said earlier,
// newest first, as many as the room left allows. Typing anything opens the Palette with what you typed. The
// clocks, the weather and what is coming come from `takumi clock today` (docs/time.md), the 12- or 24-hour
// clock from ~/.config/takumi/clock.toml. See docs/shell.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Look"
import "../Parts"

FocusScope {
    id: today
    required property var core
    required property var notices
    property bool active: false
    implicitWidth: Style.todayWidth
    implicitHeight: column.implicitHeight + Style.space(32)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int offset: 0                       // months away from this one
    property string selectedDayKey: ""           // YYYY-M-D when a day in the month is clicked
    onActiveChanged: if (active) { offset = 0; selectedDayKey = ""; nowMs = Date.now(); clockFile.reload(); read(); Qt.callLater(() => today.forceActiveFocus()); }

    function dateKey(d) { return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate(); }
    readonly property var eventDayKeys: {
        const set = {};
        for (const c of (info.coming ?? [])) {
            if (!c.at) continue;
            set[dateKey(new Date(c.at * 1000))] = true;
        }
        return set;
    }
    readonly property var selectedDayEvents: {
        if (!selectedDayKey) return [];
        return (info.coming ?? []).filter(c => c.at && dateKey(new Date(c.at * 1000)) === selectedDayKey).slice(0, 3);
    }

    readonly property var now: clock.date
    readonly property var month: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7      // 0 Sunday … 6 Saturday
    readonly property var days: {
        const y = month.getFullYear(), m = month.getMonth();
        const lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 - lead + i);
            const key = dateKey(d);
            out.push({ n: d.getDate(), key: key, label: Qt.formatDate(d, "ddd d MMM"), inMonth: d.getMonth() === m,
                       isToday: d.toDateString() === now.toDateString(), hasEvent: !!eventDayKeys[key],
                       weekend: d.getDay() === 0 || d.getDay() === 6 });
        }
        return out;
    }
    readonly property var weekdays: {
        const out = [];
        for (let i = 0; i < 7; i++) out.push(Qt.locale().dayName((firstDay + i) % 7, Locale.NarrowFormat));
        return out;
    }
    // ISO 8601: the week with the year's first Thursday is week 1.
    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    function iconFor(icon) { return !icon ? "" : (icon.startsWith("/") || icon.includes("://")) ? icon : Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon, true) : ""; }
    function when(at) {
        const d = new Date(at), f = twelve ? "h:mm AP" : "HH:mm";
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, f);
        const y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        return (d.toDateString() === y.toDateString() ? "Yesterday " : Qt.formatDate(d, "d MMM ")) + Qt.formatTime(d, f);
    }

    // The 12- or 24-hour clock: `format` in clock.toml (takumi clock format), else what takumi clock today
    // read from the language, else Qt's idea of it.
    property string fileFormat: ""
    FileView {
        id: clockFile
        path: Quickshell.env("HOME") + "/.config/takumi/clock.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { const m = text().match(/^format\s*=\s*"(12h|24h)"/m); today.fileFormat = m ? m[1] : ""; }
    }
    readonly property bool twelve: fileFormat !== "" ? fileFormat === "12h"
        : info.format ? info.format === "12h" : Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().includes("ap")

    // Beside the month: {format, zone, city, offset, clocks: [{city, zone, offset, diff}], weather, coming: [{id,
    // kind, at, made, text}]}. Read once at start, when Today opens and every half minute while it is open, so
    // it shows at once and then catches up. Offsets are seconds east of UTC: the time anywhere is worked out
    // here from the computer's own clock. A new time zone also tells the JavaScript clock (Date.timeZoneUpdated).
    property var info: ({ clocks: [], weather: "", coming: [], offset: 0, zone: "" })
    function read() { if (!reader.running) reader.running = true; }
    Process {
        id: reader
        command: ["takumi", "clock", "today"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(this.text);
                    if (today.info.zone !== "" && v.zone !== today.info.zone) Date.timeZoneUpdated();
                    today.info = v;
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: read()
    Timer { interval: 30000; repeat: true; running: today.active; onTriggered: today.read() }
    // A running timer counts down by the second while Today is open.
    property real nowMs: Date.now()
    readonly property var coming: (info.coming ?? []).filter(c => c.at * 1000 > nowMs - 60000).slice(0, 3)
    Timer { interval: 1000; repeat: true; running: today.active && today.coming.some(c => c.kind === "timer"); onTriggered: today.nowMs = Date.now() }

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function hm(h, m) { return twelve ? ((h + 11) % 12 + 1) + ":" + pad(m) + (h < 12 ? " AM" : " PM") : pad(h) + ":" + pad(m); }
    function dayOf(secs, off) { return Math.floor((Math.floor(secs) + off) / 86400); }
    function timeAt(secs, off) { const s = ((Math.floor(secs) + off) % 86400 + 86400) % 86400; return hm(Math.floor(s / 3600), Math.floor(s % 3600 / 60)); }
    // A reminder's moment: "15:00", "Tomorrow 09:00", "Fri 18:00", "12 Nov 09:00".
    function moment(secs) {
        const d = dayOf(secs, info.offset ?? 0) - dayOf(nowMs / 1000, info.offset ?? 0), t = timeAt(secs, info.offset ?? 0);
        if (d === 0) return t;
        if (d === 1) return "Tomorrow " + t;
        if (d > 1 && d < 7) return Qt.locale().dayName(((dayOf(secs, info.offset ?? 0) + 4) % 7 + 7) % 7, Locale.ShortFormat) + " " + t;
        return Qt.formatDate(new Date(secs * 1000), "d MMM ") + t;
    }
    // A timer's time left: "4:05", "1:02:05".
    function remaining(secs) {
        const s = Math.max(0, Math.round(secs - nowMs / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        return (h > 0 ? h + ":" + pad(m) : String(m)) + ":" + pad(s % 60);
    }

    // The Core's surface is Style.coreSurface tall. The day, the clocks, the month and what is coming go first;
    // the earlier messages take the room that is left, three at most, and do not show when none fits.
    readonly property int earlierRow: Style.space(40)
    readonly property int earlierGap: Style.space(6)
    readonly property int earlierRows: {
        const shown = [dayLine, solarArc, clocksRow, nav, monthGrid, pickedBar, rule, comingCol].filter(i => i.visible);
        const used = shown.reduce((sum, i) => sum + i.height, 0) + column.spacing * shown.length;
        const room = Style.coreSurface - Style.space(32) - used - earlierLabel.implicitHeight;
        return Math.max(0, Math.min(3, Math.floor(room / (earlierRow + earlierGap))));
    }
    readonly property var earlier: (notices?.recent ?? []).slice(0, earlierRows)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape: core.close(); break;
        case Qt.Key_Left: case Qt.Key_PageUp: offset--; break;
        case Qt.Key_Right: case Qt.Key_PageDown: offset++; break;
        case Qt.Key_Home: offset = 0; selectedDayKey = ""; break;
        default:
            if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { core.search(event.text); break; }
            return;
        }
        event.accepted = true;
    }
    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y;
            if (Math.abs(acc) >= 120) { today.offset += acc > 0 ? -1 : 1; acc = 0; }
        }
    }

    Column {
        id: column
        x: Style.space(16); y: Style.space(16)
        width: parent.width - Style.space(32)
        spacing: Style.space(12)

        // The day itself, and the weather when it is on (a press opens the Palette on "weather").
        Item {
            id: dayLine
            width: parent.width; height: dayName.implicitHeight + date.implicitHeight + Style.space(2)
            Label { id: dayName; micro: true; color: Theme.accent; text: Qt.locale().dayName(today.now.getDay(), Locale.LongFormat) }
            Label {
                id: weather
                visible: text !== ""
                anchors { right: parent.right; verticalCenter: dayName.verticalCenter }
                width: Math.min(implicitWidth, parent.width - dayName.implicitWidth - Style.space(12))
                horizontalAlignment: Text.AlignRight
                text: today.info.weather ?? ""
                font.pixelSize: Style.caption; dim: Style.textDim
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: today.core.search("weather") }
            }
            Label {
                id: date
                anchors.top: dayName.bottom; anchors.topMargin: Style.space(2)
                text: today.now.getDate() + " " + Qt.locale().standaloneMonthName(today.now.getMonth(), Locale.LongFormat)
                font.pixelSize: Style.space(26); font.weight: Font.Light; font.letterSpacing: -0.4
            }
            Label { anchors { right: parent.right; baseline: date.baseline } text: "Week " + today.week(today.now); font.pixelSize: Style.caption; dim: Style.textFaint }
        }

        // Phase Solar Arc: live visual position across Night -> Dawn -> Day -> Dusk; click opens Theme Studio.
        Pressable {
            id: solarArc
            width: parent.width; height: Style.solarHeight; radius: Style.rowRadius; raised: true
            accessibleName: "Phase " + Theme.phase + ". Open theme studio"
            color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
            onClicked: today.core.search("theme")
            // Dawn (06:00) -> 0.0, Day (12:00) -> 0.33, Dusk (18:00) -> 0.67, Night (00:00) -> 1.0
            readonly property real dayFrac: ((today.now.getHours() * 60 + today.now.getMinutes() - 360 + 1440) % 1440) / 1440
            Item {
                id: solarHead
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.space(12); rightMargin: Style.space(12); topMargin: Style.space(9) }
                height: Style.space(16)
                Label { anchors { left: parent.left; verticalCenter: parent.verticalCenter } micro: true; text: "Solar phase" }
                Label {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    font.pixelSize: Style.caption; color: Theme.accent
                    text: Theme.phase.charAt(0).toUpperCase() + Theme.phase.slice(1) + " · " + Theme.name
                }
            }
            // Dedicated 14 px track rail cleanly separated from the phase labels below.
            Item {
                id: track
                anchors { left: parent.left; right: parent.right; top: solarHead.bottom; leftMargin: Style.space(12); rightMargin: Style.space(12); topMargin: Style.space(8) }
                height: Style.space(14)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 2; radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accentTint(0.55) }
                        GradientStop { position: 0.35; color: Theme.accent }
                        GradientStop { position: 0.70; color: Theme.accentTint(0.55) }
                        GradientStop { position: 1.0; color: Theme.tint(0.14) }
                    }
                }
                // Luminous phase orb positioned accurately along the Dawn -> Day -> Dusk -> Night cycle.
                Rectangle {
                    width: Style.space(10); height: width; radius: width / 2
                    color: Theme.accent
                    x: Math.max(0, Math.min(parent.width - width, parent.width * solarArc.dayFrac - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Style.space(12); rightMargin: Style.space(12); bottomMargin: Style.space(8) }
                height: Style.space(14)
                Repeater {
                    model: [
                        { label: "Dawn",  pos: 0.0 },
                        { label: "Day",   pos: 0.333 },
                        { label: "Dusk",  pos: 0.667 },
                        { label: "Night", pos: 1.0 }
                    ]
                    delegate: Label {
                        required property var modelData
                        x: modelData.pos === 0 ? 0 : modelData.pos === 1 ? parent.width - implicitWidth : Math.round(parent.width * modelData.pos - implicitWidth / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label; font.pixelSize: Style.micro; dim: Style.textFaint
                    }
                }
            }
        }

        // Clocks for other cities, three at most: the city, its time, how far ahead or behind. A press opens the
        // Palette on "clock", where they are added and taken out.
        Row {
            id: clocksRow
            readonly property var cities: (today.info.clocks ?? []).slice(0, 3)
            visible: cities.length > 0
            width: parent.width
            spacing: Style.space(6)
            Repeater {
                model: clocksRow.cities
                delegate: Pressable {
                    id: cityClock
                    required property var modelData
                    readonly property real secs: today.now.getTime() / 1000
                    readonly property int dayDiff: today.dayOf(secs, modelData.offset) - today.dayOf(secs, today.info.offset ?? 0)
                    width: (clocksRow.width - clocksRow.spacing * (clocksRow.cities.length - 1)) / clocksRow.cities.length
                    height: cityName.implicitHeight + cityTime.implicitHeight + Style.space(12)
                    radius: Style.rowRadius
                    accessibleName: modelData.city + " " + cityTime.text + ", " + modelData.diff
                    onClicked: today.core.search("clock")
                    Label { id: cityName; x: Style.space(8); y: Style.space(6); width: parent.width - Style.space(16); micro: true; text: cityClock.modelData.city }
                    Row {
                        x: Style.space(8); anchors.top: cityName.bottom
                        width: parent.width - Style.space(16)
                        spacing: Style.space(6)
                        Label {
                            id: cityTime; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold
                            text: today.timeAt(cityClock.secs, cityClock.modelData.offset)
                                  + (cityClock.dayDiff > 0 ? " +1" : cityClock.dayDiff < 0 ? " −1" : "")
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, parent.width - cityTime.implicitWidth - parent.spacing)
                            text: cityClock.modelData.diff; font.pixelSize: Style.caption; dim: Style.textDim
                        }
                    }
                }
            }
        }

        // The month shown, and the way to the ones around it.
        Item {
            id: nav
            width: parent.width; height: Style.space(30)
            Label {
                anchors { left: parent.left; leftMargin: Style.space(4); verticalCenter: parent.verticalCenter }
                text: Qt.locale().standaloneMonthName(today.month.getMonth(), Locale.LongFormat)
                      + (today.month.getFullYear() !== today.now.getFullYear() ? " " + today.month.getFullYear() : "")
                font.weight: Font.DemiBold
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Style.space(4)
                Pressable {
                    visible: today.offset !== 0 || today.selectedDayKey !== ""
                    width: back.implicitWidth + Style.space(18); height: Style.space(28); radius: height / 2
                    accessibleName: "Back to today"
                    onClicked: { today.offset = 0; today.selectedDayKey = ""; }
                    Label { id: back; anchors.centerIn: parent; text: "Today"; font.pixelSize: Style.caption; color: Theme.accent }
                }
                Pressable {
                    width: Style.space(28); height: width; radius: width / 2
                    accessibleName: "Previous month"
                    onClicked: today.offset--
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; rotation: 180 }
                }
                Pressable {
                    width: Style.space(28); height: width; radius: width / 2
                    accessibleName: "Next month"
                    onClicked: today.offset++
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall }
                }
            }
        }

        Column {
            id: monthGrid
            width: parent.width
            spacing: Style.space(4)
            Row {
                Repeater {
                    model: today.weekdays
                    delegate: Label {
                        required property var modelData
                        width: column.width / 7; horizontalAlignment: Text.AlignHCenter
                        micro: true; text: modelData
                    }
                }
            }
            Grid {
                columns: 7
                Repeater {
                    model: today.days
                    delegate: Pressable {
                        id: dayCell
                        required property var modelData
                        readonly property bool picked: today.selectedDayKey === modelData.key
                        width: column.width / 7; height: Style.dayCell
                        radius: height / 2
                        accessibleName: modelData.label + (modelData.isToday ? ", today" : "")
                        color: "transparent"
                        onClicked: today.selectedDayKey = picked ? "" : modelData.key
                        Rectangle {
                            anchors.centerIn: parent
                            width: Style.dayCell - Style.space(4); height: width; radius: width / 2
                            color: dayCell.modelData.isToday ? Theme.accent
                                 : dayCell.picked ? Theme.accentTint(Style.fillTileOn)
                                 : dayCell.hovered ? Theme.tint(Style.fillHover * 2) : "transparent"
                            border.width: dayCell.picked && !dayCell.modelData.isToday ? Style.hairline : 0
                            border.color: Theme.accentTint(Style.rimLit)
                        }
                        Label {
                            anchors.centerIn: parent
                            text: dayCell.modelData.n
                            font.weight: dayCell.modelData.isToday || dayCell.picked ? Font.DemiBold : Font.Medium
                            color: dayCell.modelData.isToday ? Theme.background
                                 : dayCell.picked ? Theme.accent
                                 : Theme.withAlpha(Theme.foreground, !dayCell.modelData.inMonth ? 0.26 : dayCell.modelData.weekend ? Style.textDim : 0.92)
                        }
                        Rectangle {
                            visible: dayCell.modelData.hasEvent && !dayCell.modelData.isToday
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Style.space(3) }
                            width: Style.space(4); height: width; radius: width / 2
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        // Selected day quick-agenda bar: shows that date's reminders or a one-click "Add reminder".
        Row {
            id: pickedBar
            visible: today.selectedDayKey !== ""
            width: parent.width
            spacing: Style.space(8)
            readonly property var pickedDay: today.days.find(d => d.key === today.selectedDayKey) ?? null
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - addRem.width - parent.spacing
                font.pixelSize: Style.caption; dim: Style.textDim
                text: {
                    const lbl = pickedBar.pickedDay ? pickedBar.pickedDay.label : "";
                    const ev = today.selectedDayEvents;
                    return ev.length > 0 ? lbl + " · " + ev.map(e => e.text || "Timer").join(", ") : lbl + " · Nothing scheduled";
                }
            }
            Pressable {
                id: addRem
                width: addRemLbl.implicitWidth + Style.space(16); height: Style.space(24); radius: height / 2
                accessibleName: "Add reminder"
                color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.accentTint(0.24) : Theme.accentTint(0.14)
                onClicked: today.core.search("remind ")
                Label { id: addRemLbl; anchors.centerIn: parent; text: "+ Remind"; font.pixelSize: Style.caption; color: Theme.accent }
            }
        }

        Rectangle { id: rule; width: parent.width; height: Style.hairline; color: Theme.tint(Style.lineHair) }

        // What is coming: timers counting down, with a line that shortens as they run, and reminders with their
        // moment. Three at most; a press opens the Palette on them, where each can be stopped or cancelled.
        Column {
            id: comingCol
            visible: today.coming.length > 0
            width: parent.width
            spacing: Style.space(4)
            Label { micro: true; text: "Coming up" }
            Repeater {
                model: today.coming
                delegate: Pressable {
                    id: soon
                    required property var modelData
                    readonly property bool isTimer: modelData.kind === "timer"
                    readonly property string words: modelData.text !== "" ? modelData.text : "Timer"
                    width: comingCol.width; height: Style.space(30)
                    radius: Style.rowRadius
                    accessibleName: words + ", " + (isTimer ? today.remaining(modelData.at) + " left" : today.moment(modelData.at))
                    onClicked: today.core.search(isTimer ? "timer" : "reminders")
                    Icon { id: soonIcon; x: Style.space(6); anchors.verticalCenter: parent.verticalCenter; name: soon.isTimer ? "clock" : "bell"; size: Style.iconSmall }
                    Label {
                        anchors { left: soonIcon.right; leftMargin: Style.space(10); right: soonWhen.left; rightMargin: Style.space(10); verticalCenter: parent.verticalCenter }
                        text: soon.words
                    }
                    Label {
                        id: soonWhen
                        anchors { right: parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
                        text: soon.isTimer ? today.remaining(soon.modelData.at) : today.moment(soon.modelData.at)
                        color: soon.isTimer ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim)
                        font.weight: soon.isTimer ? Font.DemiBold : Font.Medium
                    }
                    Rectangle {
                        visible: soon.isTimer
                        anchors { left: parent.left; bottom: parent.bottom; leftMargin: Style.space(6) }
                        height: Style.space(2); radius: height / 2
                        color: Theme.accentTint(0.5)
                        width: (parent.width - Style.space(12)) * Math.max(0, Math.min(1,
                               (soon.modelData.at - today.nowMs / 1000) / Math.max(1, soon.modelData.at - soon.modelData.made)))
                    }
                }
            }
        }

        // What your apps said, newest first, in the room that is left.
        Column {
            id: earlierCol
            readonly property bool none: (today.notices?.recent ?? []).length === 0
            visible: today.earlierRows > 0
            width: parent.width
            spacing: today.earlierGap
            Label { id: earlierLabel; micro: true; text: "Earlier" }
            Label { visible: earlierCol.none; text: "Nothing from your apps yet"; font.pixelSize: Style.caption; dim: Style.textFaint }
            Repeater {
                model: today.earlier
                delegate: Item {
                    id: said
                    required property var modelData
                    width: column.width; height: today.earlierRow
                    readonly property string path: today.iconFor(modelData.icon)
                    Item {
                        id: mark
                        width: Style.space(26); height: width
                        anchors.verticalCenter: parent.verticalCenter
                        IconImage { anchors.fill: parent; source: said.path; visible: said.path !== "" }
                        Icon { anchors.centerIn: parent; visible: said.path === ""; name: "bell"; size: Style.iconSmall }
                    }
                    Column {
                        anchors { left: mark.right; leftMargin: Style.space(12); right: parent.right; verticalCenter: parent.verticalCenter }
                        Label { width: parent.width; text: said.modelData.summary || said.modelData.app; font.weight: Font.DemiBold }
                        Label { width: parent.width; font.pixelSize: Style.caption; dim: Style.textDim
                            text: [said.modelData.app, today.when(said.modelData.at)].filter(s => s).join(" · ") }
                    }
                }
            }
        }
    }
}
