//@ pragma UseQApplication
// Takumi shell: the Sky (background), the Core (status, notices, the Palette) and the Lock, in one
// Quickshell instance. Services are created once here and handed to every screen.
import QtQuick
import Quickshell
import Quickshell.Io
import "Look"
import "Sources"
import "Sky"
import "Core"
import "Lock"

ShellRoot {
    id: root

    // Ids differ from the property names they feed: `niri: niri` would bind a property to itself.
    Niri { id: niriService }
    Poll { id: pollService }
    CoreState { id: coreState; niri: niriService }
    Notices { id: noticesService; core: coreState }
    Approvals { id: approvalsService }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property var modelData
            Sky   { screen: perScreen.modelData }
            // The output name comes from the screen list, not the window: a window's screen can be unset
            // while it is unmapped, which would feed back into whether it is mapped.
            Scrim { screen: perScreen.modelData; output: perScreen.modelData.name; core: coreState }
            Core  { screen: perScreen.modelData; output: perScreen.modelData.name; niri: niriService; poll: pollService; core: coreState; approvals: approvalsService; notices: noticesService }
        }
    }

    Lock { id: lockScreen; poll: pollService; niri: niriService }

    // niri saved a screenshot: the Core shows it (Sources/CoreState.qml shot).
    Connections { target: niriService; function onScreenshot(path) { coreState.shot(path); } }

    // You reached your desktop. A room on its first start is judged by this (see commands/room/health).
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", ": > /run/takumi/desktop-ready 2>/dev/null || true"])

    // The first login opens the Core on its own, once, with the start rows (takumi palette index start).
    Process {
        running: true
        command: ["sh", "-c", 'f="$HOME/.local/state/takumi/firstlight"; [ -e "$f" ] && exit 1; mkdir -p "${f%/*}"; : > "$f"']
        onExited: code => { if (code === 0) firstLight.start(); }
    }
    Timer { id: firstLight; interval: 2500; onTriggered: coreState.show() }

    // qs -c takumi ipc call core toggle | show | close | quick | today | search <text> | notice <icon> <title> <detail> <value>
    IpcHandler {
        target: "core"
        function toggle(): void { coreState.toggle(); }
        function show(): void { coreState.show(); }
        function close(): void { coreState.close(); }
        function search(text: string): void { coreState.search(text); }
        function quick(): void { coreState.quick(); }
        function today(): void { coreState.today(); }
        function notice(icon: string, title: string, detail: string, value: int): void { coreState.notice(icon, title, detail, value); pollService.refresh(); }
        function announce(icon: string, title: string, detail: string, seconds: int): void { coreState.announce(icon, title, detail, seconds); }
        function offer(icon: string, title: string, detail: string, open: string, seconds: int): void { coreState.offer(icon, title, detail, open, seconds); pollService.refresh(); }
    }
    IpcHandler { target: "lock";  function lock(): void { lockScreen.lock(); } }
    // takumi approve askpass: a command run with sudo -A wants your password; the answer goes to the FIFO.
    IpcHandler { target: "approvals"; function ask(fifo: string, why: string): void { approvalsService.ask(fifo, why); } }
    // qs -c takumi ipc call notices dnd | act | clear | next | previous (docs/notifications.md)
    IpcHandler {
        target: "notices"
        function dnd(): void { noticesService.refreshDnd(); }
        function act(): void { coreState.actNotice(); }
        function clear(): void { coreState.clearNotices(); }
        function next(): void { noticesService.next(); }
        function previous(): void { noticesService.previous(); }
    }
    // Zoom, docked along the top of the focused screen (Core/Zoom.qml, docs/accessibility.md). Each call answers
    // "on <level>" or "off": qs -c takumi ipc call zoom toggle | start | hide | closer | farther | pan <direction> | state
    Zoom { id: zoom; niri: niriService }
    IpcHandler {
        target: "zoom"
        function toggle(): string { return zoom.toggle(); }
        function start(): string { return zoom.turnOn(); }   // not "show": qs ipc reads that word as its own
        function hide(): string { return zoom.turnOff(); }
        function closer(): string { return zoom.closer(); }
        function farther(): string { return zoom.farther(); }
        function pan(direction: string): string { return zoom.pan(direction); }
        function state(): string { return zoom.said(); }
    }
    IpcHandler { target: "theme"; function reload(): void { Theme.reload(); } }
    // Your camera in a corner while a recording runs (takumi screen record --camera). Loaded lazily, so a
    // computer without Qt Multimedia keeps its shell: show() then answers false and the recording goes on.
    LazyLoader { id: cameraBubble; loading: true; source: "Core/CameraBubble.qml" }
    IpcHandler {
        target: "camera"
        function show(x: int, y: int, width: int, height: int): bool {
            if (!cameraBubble.item) return false;
            cameraBubble.item.showIn(x, y, width, height);
            return true;
        }
        function hide(): void { if (cameraBubble.item) cameraBubble.item.hide(); }
    }
    IpcHandler { target: "poll";  function refresh(): void { pollService.refresh(); } }
}
