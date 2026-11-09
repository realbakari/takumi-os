// The second question: which keyboard this is, before anything is typed that matters. The list starts on
// the firmware's guess, or the chosen language's; a pick changes the keyboard at once (takumi setup keyboard), so the field under the
// list tries it. Enter picks the row the arrows rest on; Enter on the chosen one goes on.
import QtQuick
import QtQuick.Window
import "../Look"
import "../Parts"

Page {
    id: page
    key: "keyboard"
    title: "Which keyboard is this?"
    detail: "Type a language or a country to find yours. It works at once, so try it below."
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
        if (!q) return page.setup.keyboards;
        const words = q.split(/\s+/);
        return page.setup.keyboards
            .map((k, i) => ({ item: k, i: i, s: page.score(words, k.name + " " + k.variant, k.layout, k.variant === "") }))
            .filter(r => r.s > 0)
            .sort((a, b) => b.s - a.s || a.i - b.i)
            .map(r => r.item);
    }
    function isChosen(k) { return k.layout === page.setup.layout && k.variant === page.setup.variant; }
    function settle() {
        const i = found.findIndex(k => isChosen(k));
        list.currentIndex = i >= 0 && !search.text ? i : 0;
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }
    function pick() {
        const k = found[list.currentIndex];
        if (!k) return;
        if (isChosen(k)) page.tryGo(); else page.setup.pickKeyboard(k);
    }
    // After the list has its new rows, or it scrolls the old ones.
    onFoundChanged: Qt.callLater(settle)
    onShown: { search.input.forceActiveFocus(); settle(); }

    Field {
        id: search
        width: parent.width
        hint: "Search keyboards"
        onAccepted: page.pick()
        onEscaped: page.goBack()
        onUp: list.currentIndex = Math.max(0, list.currentIndex - 1)
        onDown: list.currentIndex = Math.min(page.found.length - 1, list.currentIndex + 1)
    }
    ListView {
        id: list
        width: parent.width
        // Six rows, fewer on a short screen, so the glass always fits.
        height: Math.min(Style.setupList, Math.max(Style.rowHeight * 3, Window.height - Style.space(620)))
        clip: true
        model: page.found
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Style.glide
        delegate: Choice {
            required property var modelData
            required property int index
            title: modelData.name
            tag: modelData.variant ? "" : modelData.layout
            chosen: page.isChosen(modelData)
            lit: index === list.currentIndex
            onClicked: { list.currentIndex = index; page.setup.pickKeyboard(modelData); }
        }
        Label {
            anchors.centerIn: parent
            visible: page.found.length === 0 && page.setup.keyboards.length > 0
            text: "No keyboard by that name"
            dim: Style.textDim
        }
    }
    Field { id: tryit; width: parent.width; hint: "Try it here"; onAccepted: page.tryGo(); onEscaped: search.input.forceActiveFocus() }
}
