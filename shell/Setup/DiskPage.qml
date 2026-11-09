// The last question: which disk. Each says what is on it now; the one chosen says what erasing it takes
// away. Erasing asks twice: the button turns red and waits five seconds for the second press.
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "disk"
    title: "Where should Takumi go?"
    detail: page.setup.disks.filter(d => d.ok).length > 1 ? "Choose a disk. Takumi takes all of it." : "Takumi takes all of this disk."
    property bool armed: false
    readonly property var chosen: page.setup.diskInfo
    readonly property var facts: page.setup.facts
    readonly property bool flat: (facts.battery ?? -1) >= 0 && facts.plugged === false && facts.battery < 20
    readonly property bool beside: page.setup.mode === "beside"
    next: beside ? (armed ? "Press again to install" : "Install beside Windows") : (armed ? "Press again to erase it" : "Erase and install")
    warn: armed && !beside
    canGo: !!chosen && chosen.ok && !flat
    signal install()
    onGo: {
        if (!armed) { armed = true; disarm.restart(); return; }
        armed = false; disarm.stop(); page.install();
    }
    onCurrentChanged: armed = false
    Timer { id: disarm; interval: 5000; onTriggered: page.armed = false }
    Keys.onUpPressed: page.step(-1)
    Keys.onDownPressed: page.step(1)
    function step(by) {
        const ok = page.setup.disks.filter(d => d.ok);
        const i = ok.findIndex(d => d.path === page.setup.disk);
        if (ok.length) { page.setup.pickDisk(ok[Math.max(0, Math.min(ok.length - 1, i + by))].path); armed = false; }
    }
    function holds(d) {
        return { Windows: "Windows is on it", macOS: "macOS is on it", Linux: "Linux is on it", Takumi: "Takumi is on it",
                 files: "Files are on it", nothing: "Empty" }[d.holds] ?? "";
    }

    Column {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
            model: page.setup.disks
            delegate: Pressable {
                required property var modelData
                readonly property bool chosen: modelData.path === page.setup.disk
                width: parent.width
                height: Style.space(64)
                enabled: modelData.ok
                opacity: modelData.ok ? 1 : 0.45
                selected: chosen
                accessibleName: modelData.name + ", " + modelData.sizeText + ", " + page.holds(modelData)
                onClicked: { page.setup.pickDisk(modelData.path); page.armed = false; }
                Icon { x: Style.space(18); anchors.verticalCenter: parent.verticalCenter; name: modelData.kind === "usb" ? "usb" : "drive"; size: Style.space(24); color: chosen ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim) }
                Column {
                    anchors { left: parent.left; leftMargin: Style.space(58); right: parent.right; rightMargin: Style.space(44); verticalCenter: parent.verticalCenter }
                    spacing: Style.space(3)
                    Label { width: parent.width; text: modelData.name + "  ·  " + modelData.sizeText; font.pixelSize: Style.subtitle }
                    Label { width: parent.width; text: modelData.ok ? page.holds(modelData) : modelData.why; dim: Style.textDim; font.weight: Font.Normal }
                }
                Icon {
                    anchors { right: parent.right; rightMargin: Style.space(16); verticalCenter: parent.verticalCenter }
                    name: "check"; size: Style.iconSmall; color: Theme.accent; visible: chosen
                }
            }
        }
    }
    Label {
        width: parent.width
        visible: page.setup.disksRead && page.setup.disks.length === 0
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "No disk to put Takumi on. Connect one, and it shows here."
        dim: Style.textDim
    }
    // Windows with room beside it: keep it, or erase the whole disk.
    Column {
        width: parent.width
        spacing: Style.space(4)
        visible: !!page.chosen && page.chosen.beside
        Choice {
            width: parent.width
            title: "Beside Windows"
            detail: "Uses the " + (page.chosen ? page.chosen.freeText : "") + " of free space; Windows stays"
            chosen: page.beside
            onClicked: { page.setup.mode = "beside"; page.armed = false; }
        }
        Choice {
            width: parent.width
            title: "Erase the whole disk"
            detail: "Windows and every file on the disk go"
            chosen: !page.beside
            onClicked: { page.setup.mode = "erase"; page.armed = false; }
        }
    }
    Label {
        width: parent.width
        visible: !!page.chosen && page.chosen.holds === "Windows" && !page.chosen.beside && page.chosen.ok
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "To keep Windows, make room in it first: in Windows, open Disk Management, right-click the C: drive and choose Shrink Volume, 40 GB or more. Then start this disc again."
        dim: Style.textDim
        font.pixelSize: Style.body
    }
    Label {
        width: parent.width
        visible: page.beside
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: "Windows stays as it is. When the computer starts, a menu offers Takumi and Windows for three seconds."
              + (page.chosen && page.chosen.bitlocker ? " Windows will ask once for its BitLocker recovery key afterwards: have it ready (aka.ms/myrecoverykey)." : "")
        color: Theme.accent
        font.pixelSize: Style.body
    }
    Label {
        width: parent.width
        visible: !!page.chosen && !page.beside
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        readonly property string os: page.chosen ? page.chosen.holds : ""
        text: os === "nothing" ? "It is empty."
            : ["Windows", "macOS", "Linux", "Takumi"].indexOf(os) >= 0 ? "Everything on it will be erased: " + os + " and every file with it."
            : "Everything on it will be erased."
        color: os === "nothing" ? Theme.withAlpha(Theme.foreground, Style.textDim) : Theme.red
        font.pixelSize: Style.body
    }
    Label {
        width: parent.width
        visible: (page.facts.battery ?? -1) >= 0 && page.facts.plugged === false && page.facts.battery < 50
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: page.flat ? "Plug in the charger first: the battery is too low to finish." : "Plug in the charger: installing takes a while."
        color: page.flat ? Theme.red : Theme.accent
        font.pixelSize: Style.body
    }
}
