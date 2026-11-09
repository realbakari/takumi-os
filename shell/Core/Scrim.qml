// The dimming behind the open Core: a full-screen surface on the top layer, under the Core (overlay
// layer) and over windows. A click on it closes the Core. Mapped only while it is open or fading.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Look"

PanelWindow {
    id: win
    required property var core
    required property string output
    readonly property bool open: core.openOn !== "" && core.openOn === output
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || shade.opacity > 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "takumi-scrim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: shade
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, Style.scrim)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Style.enter : Style.exit } }
    }
    MouseArea { anchors.fill: parent; onClicked: win.core.close() }
}
