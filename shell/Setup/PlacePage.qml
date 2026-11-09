// The third question: where the computer is, for its clock. The sky turns to the time of day there. With a
// network, "Find it online" asks ipinfo.io once, and only when pressed (takumi setup zones --guess).
import QtQuick
import QtQuick.Window
import "../Look"
import "../Parts"

Page {
    id: page
    key: "place"
    title: "Where are you?"
    detail: "For the clock and the sky. Type your city, or one near it."
    other: page.setup.facts.online === true && page.setup.lookup !== "asking" ? "Find it online" : ""
    onGoOther: { search.text = ""; page.setup.guessZone(); }
    // Best first: a whole word of the name, then the layout's code or a word that starts one, then anywhere,
    // and a base layout before its variants ("english us" finds English (US) before English (Dvorak)).
    function score(words, name, code, base) {
        const parts = name.toLowerCase().split(/[^a-z0-9\u00c0-\u024f]+/).filter(w => w);
        let total = base ? 0.5 : 0;
        for (const w of words) {
            if (parts.indexOf(w) >= 0) total += 3;
            else if (w === code) total += 2;
            else if (parts.some(p => p.startsWith(w))) total += 2;
            else if (name.toLowerCase().indexOf(w) >= 0 || code.indexOf(w) >= 0) total += 1;
            else return 0;
        }
        return total;
    }
    readonly property var found: {
        const q = search.text.trim().toLowerCase();
        if (!q) return page.setup.zones;
        const words = q.split(/\s+/);
        return page.setup.zones
            .map((z, i) => ({ item: z, i: i, s: page.score(words, z.city + " " + z.country, z.zone.toLowerCase(), true) }))
            .filter(r => r.s > 0)
            .sort((a, b) => b.s - a.s || a.i - b.i)
            .map(r => r.item);
    }
    function settle() {
        const i = found.findIndex(z => z.zone === page.setup.zone);
        list.currentIndex = i >= 0 && !search.text ? i : 0;
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }
    function pick() {
        const z = found[list.currentIndex];
        if (!z) return;
        if (z.zone === page.setup.zone) page.tryGo(); else page.setup.pickZone(z.zone);
    }
    // After the list has its new rows, or it scrolls the old ones.
    onFoundChanged: Qt.callLater(settle)
    onShown: { search.input.forceActiveFocus(); settle(); }

    Field {
        id: search
        width: parent.width
        hint: "Search cities"
        onAccepted: page.pick()
        onEscaped: page.goBack()
        onUp: list.currentIndex = Math.max(0, list.currentIndex - 1)
        onDown: list.currentIndex = Math.min(page.found.length - 1, list.currentIndex + 1)
    }
    ListView {
        id: list
        width: parent.width
        // Six rows, fewer on a short screen, so the glass always fits.
        height: Math.min(Style.setupList, Math.max(Style.rowHeight * 3, Window.height - Style.space(580)))
        clip: true
        model: page.found
        boundsBehavior: Flickable.StopAtBounds
        delegate: Choice {
            required property var modelData
            required property int index
            title: modelData.city
            detail: modelData.country
            chosen: modelData.zone === page.setup.zone
            lit: index === list.currentIndex
            onClicked: { list.currentIndex = index; page.setup.pickZone(modelData.zone); }
        }
        Label {
            anchors.centerIn: parent
            visible: page.found.length === 0 && page.setup.zones.length > 0
            text: "No city by that name: try a bigger one nearby"
            dim: Style.textDim
        }
    }
    Row {
        spacing: Style.space(10)
        visible: page.setup.here.time !== ""
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: Style.icon; color: Theme.accent }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: page.setup.here.time + " on " + page.setup.here.day + " in " + page.setup.zoneCity
            font.pixelSize: Style.subtitle
        }
    }
    Label {
        width: parent.width
        visible: page.setup.facts.online === true
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: page.setup.lookup === "asking" ? "Asking ipinfo.io where this network is…"
            : page.setup.lookup === "failed" ? "ipinfo.io did not know: type your city instead."
            : page.setup.lookup === "found" ? "Found online, from where this network is."
            : "Find it online asks ipinfo.io where this network is, once."
        color: page.setup.lookup === "failed" ? Theme.red : Theme.withAlpha(Theme.foreground, Style.textMicro)
        font.pixelSize: Style.caption
    }
}
