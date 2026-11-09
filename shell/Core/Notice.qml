// A notice: the Core widens to say one thing and settles back. Takumi's own (volume, brightness, a theme, a
// command that ran; `takumi notice` over IPC) and messages from apps share it: an app's icon with the number
// of its messages waiting, a picture (a screenshot), a colour (an icon written as "#5ad7ff"), a meter, a
// one-time code to copy, the app's own buttons, and "3 more" when others wait behind it. The pointer resting
// on it keeps it. A press acts on it (opens what it is about, or the app's default action), the right button
// puts it away, "3 more" brings the next one. See docs/notifications.md.
import QtQuick
import QtQuick.Window
import Quickshell
import "../Look"
import "../Parts"

Item {
    id: notice
    required property var core
    readonly property bool swatch: /^#[0-9a-fA-F]{6}$/.test(core.noticeIcon)
    readonly property var actions: core.noticeActions ?? []
    // Links in an app's message (the notification spec's <a href="…">, or an address written out) open in the
    // browser. Only web and mail links: a message never opens a file or runs anything. The line on show draws
    // them in the accent; a link elsewhere in the message gets an "Open link" button.
    readonly property string body: core.noticeSource ? String(core.noticeSource.body ?? "") : ""
    readonly property var links: linksIn(body)
    readonly property string detailMarkup: linked(core.noticeDetail, links)
    readonly property string hiddenLink: links.length && detailMarkup.indexOf("<a ") < 0 ? links[0].href : ""
    function safe(href) { return /^(https?:\/\/|mailto:)/i.test(href); }
    function linksIn(text) {
        const out = [], re = /<a\s[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
        let m;
        while ((m = re.exec(text)) !== null) {
            const href = core.plain(m[1]).trim();
            if (safe(href)) out.push({ text: core.plain(m[2]).trim(), href: href });
        }
        const bare = /\b(https?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)])/gi, plain = core.plain(text.replace(/<a\s[\s\S]*?<\/a>/gi, " "));
        while ((m = bare.exec(plain)) !== null) out.push({ text: m[1], href: m[1] });
        return out;
    }
    function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
    // The line, escaped, with each link's words (or the address itself) made a link, first come first.
    function linked(line, ls) {
        if (!line) return "";
        const spans = [];
        for (const l of ls) {
            const at = l.text ? line.indexOf(l.text) : -1;
            if (at < 0 || spans.some(s => at < s.end && at + l.text.length > s.start)) continue;
            spans.push({ start: at, end: at + l.text.length, href: l.href });
        }
        spans.sort((a, b) => a.start - b.start);
        let out = "", from = 0;
        for (const s of spans) {
            out += esc(line.slice(from, s.start)) + '<a href="' + esc(s.href) + '">' + esc(line.slice(s.start, s.end)) + "</a>";
            from = s.end;
        }
        return out + esc(line.slice(from));
    }
    function openLink(href) {
        if (!safe(href)) return;
        Quickshell.execDetached(["gio", "open", href]);
        core.dismissNotice();
    }
    // The words give way first, so the notice never grows past the screen's edges.
    readonly property int room: (notice.Window.width > 0 ? notice.Window.width : Style.space(1280)) - Style.gap * 2
                                - Style.corePadLeft - Style.corePadRight - Style.space(6)
    readonly property int others: slot.width + titleLabel.width + row.spacing * 2
                                  + (meter.visible ? meter.width + valueText.width + row.spacing * 2 : 0)
                                  + (codeChip.visible ? codeChip.width + row.spacing : 0)
                                  + (chips.visible ? chips.width + row.spacing : 0)
                                  + (moreChip.visible ? moreChip.width + row.spacing : 0)
                                  + (linkChip.visible ? linkChip.width + row.spacing : 0)
    implicitWidth: row.implicitWidth + Style.corePadLeft + Style.corePadRight + Style.space(4)
    implicitHeight: Style.coreHeight
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.AlertMessage
    Accessible.name: [core.noticeTitle, core.noticeDetail, core.noticeGroup > 1 ? core.noticeGroup + " messages" : "",
                      core.noticeMore > 0 ? core.noticeMore + " more" : ""].filter(s => s !== "").join(", ")
    // A screen reader says each new notice (Qt's announcements, from Qt 6.8; before that it says nothing more).
    function speak() {
        const words = notice.Accessible.name;
        if (!words || !notice.visible) return;
        try { if (typeof notice.Accessible.announce === "function") notice.Accessible.announce(words); } catch (e) {}
    }
    onVisibleChanged: if (visible) speak()
    Connections { target: notice.core; function onNoticeSerialChanged() { notice.speak(); } }

    // A press acts on the notice; the right or middle button puts it away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.LeftButton ? notice.core.activateNotice() : notice.core.dismissNotice()
    }

    Row {
        id: row
        x: Style.corePadLeft + Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(12)

        // The icon: a stroke icon, a colour, an app's icon with the number of its messages, or a screenshot.
        Item {
            id: slot
            anchors.verticalCenter: parent.verticalCenter
            width: notice.core.noticeThumb ? Style.space(48) : Style.space(20)
            height: notice.core.noticeThumb ? Style.space(30) : Style.space(20)
            Icon { anchors.centerIn: parent; visible: notice.core.noticeImage === "" && !notice.swatch; name: notice.core.noticeIcon; size: Style.iconSmall; color: Theme.accent }
            Rectangle {
                visible: notice.swatch
                anchors.centerIn: parent
                width: Style.space(18); height: width; radius: width / 2
                color: notice.swatch ? notice.core.noticeIcon : "transparent"
                border.width: Style.hairline; border.color: Theme.tint(0.3)
            }
            Image {
                visible: notice.core.noticeImage !== "" && !notice.core.noticeThumb
                anchors.fill: parent
                source: notice.core.noticeThumb ? "" : notice.core.noticeImage
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
            }
            // A screenshot, small, in the Core.
            Image {
                visible: notice.core.noticeThumb
                anchors.fill: parent
                source: notice.core.noticeThumb ? notice.core.noticeImage : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Style.space(160)
                asynchronous: true
                clip: true
            }
            Rectangle { visible: notice.core.noticeThumb; anchors.fill: parent; color: "transparent"; radius: Style.space(3); border.width: Style.hairline; border.color: Theme.tint(0.22) }
            // Several messages from this app: their number on its icon.
            Rectangle {
                visible: notice.core.noticeGroup > 1
                anchors { right: parent.right; top: parent.top; rightMargin: -Style.space(7); topMargin: -Style.space(6) }
                width: Math.max(height, groupCount.implicitWidth + Style.space(8)); height: Style.space(15); radius: height / 2
                color: Theme.accent
                Label { id: groupCount; anchors.centerIn: parent; text: String(notice.core.noticeGroup); color: Theme.surface; font.pixelSize: Style.micro; font.weight: Font.DemiBold }
            }
        }
        Label { id: titleLabel; anchors.verticalCenter: parent.verticalCenter; text: notice.core.noticeTitle; font.weight: Font.DemiBold; width: Math.min(implicitWidth, Style.space(360)) }
        Label {
            anchors.verticalCenter: parent.verticalCenter; dim: Style.textDim; visible: notice.core.noticeDetail !== ""
            // Takumi's own notices stay plain text; an app's message may carry links, escaped here.
            textFormat: notice.core.noticeSource ? Text.StyledText : Text.PlainText
            text: notice.core.noticeSource ? notice.detailMarkup : notice.core.noticeDetail
            linkColor: Theme.accent
            onLinkActivated: link => notice.openLink(link)
            width: Math.max(0, Math.min(implicitWidth, Style.space(520), notice.room - notice.others))
        }
        // The level as twenty segments that light one by one, the last lit one brightest.
        Row {
            id: meter
            visible: notice.core.noticeValue >= 0
            anchors.verticalCenter: parent.verticalCenter
            readonly property int count: 20
            readonly property int lit: Math.ceil(Math.max(0, Math.min(100, notice.core.noticeValue)) / (100 / count))
            spacing: Style.space(2)
            width: Style.space(120)
            Repeater {
                model: meter.count
                Rectangle {
                    required property int index
                    readonly property bool on: index < meter.lit
                    readonly property bool lead: index === meter.lit - 1
                    width: (meter.width - meter.spacing * (meter.count - 1)) / meter.count
                    height: Style.space(lead ? 10 : 7)
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Style.space(1.5)
                    color: lead ? Qt.lighter(Theme.accent, 1.35) : on ? Theme.accent : Theme.tint(0.14)
                    Behavior on color { ColorAnimation { duration: Style.quick } }
                    Behavior on height { NumberAnimation { duration: Style.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }
                }
            }
        }
        Label {
            id: valueText
            visible: notice.core.noticeValue >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: String(notice.core.noticeValue); dim: Style.textDim
            horizontalAlignment: Text.AlignRight
            TextMetrics { id: widest; font: valueText.font; text: "100" }
            width: widest.width
        }
        // "Your code is 482913": copy it without opening the app.
        NoticeChip { id: codeChip; visible: notice.core.noticeCode !== ""; text: "Copy " + notice.core.noticeCode; onActivated: notice.core.copyCode() }
        // The app's own buttons ("Reply", "Mark as read", "See why"), at most three.
        Row {
            id: chips
            visible: notice.actions.length > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Repeater {
                model: notice.actions
                delegate: NoticeChip {
                    required property var modelData
                    text: modelData.text
                    onActivated: notice.core.invokeNoticeAction(modelData.id)
                }
            }
        }
        // A link further down the message than the line on show.
        NoticeChip { id: linkChip; visible: notice.hiddenLink !== ""; strong: false; text: "Open link"; onActivated: notice.openLink(notice.hiddenLink) }
        // Others waiting behind this one: a press brings the next.
        NoticeChip { id: moreChip; visible: notice.core.noticeMore > 0; strong: false; text: notice.core.noticeMore + " more"; onActivated: notice.core.nextNotice() }
    }

    // The pointer resting anywhere on the notice keeps it. On top and taking no button, so presses reach the
    // notice and its buttons below.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: notice.core.holdNotice(containsMouse)
    }
}
