// The background of every screen: the painted sky on the background layer, under everything.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Look"

PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "takumi-sky"
    color: Theme.background
    SkyCanvas { anchors.fill: parent }
}
