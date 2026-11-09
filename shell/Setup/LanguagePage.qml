// The first question: the language the apps and the desktop speak. The list starts on the firmware's guess
// (at a first start, on the one the computer was set up with); a pick turns the keyboard and the place to
// where its people mostly are, unless they were chosen already. Enter picks the row the arrows rest on;
// Enter on the chosen one goes on. The setup screen itself stays in English.
import QtQuick
import QtQuick.Window
import "../Look"
import "../Parts"

Page {
    id: page
    key: "language"
    title: "Which language?"
    detail: "For the apps and the desktop. Type a language or a country to find yours."
    back: ""
    // Best first: a whole word of the name, then the language's code or a word that starts one, then anywhere
    // ("portuguese brazil" finds Portuguese (Brazil) before Portuguese (Portugal)).
    function score(words, name, code) {
        const parts = name.toLowerCase().split(/[^a-z0-9À-ɏ]+/).filter(w => w);
        let total = 0;
        for (const w of words) {
            if (parts.indexOf(w) >= 0) total += 3;
            else if (code.startsWith(w)) total += 2;
            else if (parts.some(p => p.startsWith(w))) total += 2;
            else if (name.toLowerCase().indexOf(w) >= 0) total += 1;
            else return 0;
        }
        return total;
    }
    readonly property var found: {
        const q = search.text.trim().toLowerCase();
        if (!q) return page.setup.languages;
        const words = q.split(/\s+/);
        return page.setup.languages
            .map((l, i) => ({ item: l, i: i, s: page.score(words, l.name + " " + (l.own || ""), l.code.toLowerCase()) }))
            .filter(r => r.s > 0)
            .sort((a, b) => b.s - a.s || a.i - b.i)
            .map(r => r.item);
    }
    function settle() {
        const i = found.findIndex(l => l.code === page.setup.locale);
        list.currentIndex = i >= 0 && !search.text ? i : 0;
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }
    function pick() {
        const l = found[list.currentIndex];
        if (!l) { page.tryGo(); return; }
        if (l.code === page.setup.locale) page.tryGo(); else page.setup.pickLanguage(l);
    }
    // After the list has its new rows, or it scrolls the old ones.
    onFoundChanged: Qt.callLater(settle)
    onShown: { search.input.forceActiveFocus(); settle(); }

    Field {
        id: search
        width: parent.width
        hint: "Search languages"
        onAccepted: page.pick()
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
        highlightMoveDuration: Style.glide
        delegate: Choice {
            required property var modelData
            required property int index
            title: modelData.name
            detail: modelData.own || ""
            chosen: modelData.code === page.setup.locale
            lit: index === list.currentIndex
            onClicked: { list.currentIndex = index; page.setup.pickLanguage(modelData); }
        }
        Label {
            anchors.centerIn: parent
            visible: page.found.length === 0 && page.setup.languages.length > 0
            text: "No language by that name"
            dim: Style.textDim
        }
    }
    Label {
        width: parent.width
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "This setup is in English. Takumi starts in " + page.setup.localeName + "."
        dim: Style.textMicro
        font.pixelSize: Style.caption
    }
}
