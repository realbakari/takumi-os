// One event stream from niri for the whole shell. Everything else binds to these properties.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: niri
    property var workspaces: []        // niri Workspace objects
    property var windows: []           // niri Window objects
    property int focusedWindowId: -1
    property bool overviewOpen: false
    property bool connected: false
    property var layouts: []           // keyboard layout names, as niri knows them
    property int layoutIdx: 0
    signal screenshot(string path)     // niri saved (or only copied: "") a screenshot

    readonly property string focusedOutput: workspaces.find(w => w.is_focused)?.output ?? ""
    function focusedWindow() { return windows.find(w => w.id === focusedWindowId) ?? null; }
    function workspacesOn(output) { return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx); }
    function activeWorkspace(output) { return workspaces.find(w => w.output === output && w.is_active) ?? null; }

    // Columns of the active workspace on an output, left to right: width in px, focused, a window to focus.
    function columnsOn(output) {
        const ws = activeWorkspace(output);
        if (!ws) return [];
        const cols = {};
        for (const w of windows) {
            if (w.workspace_id !== ws.id || w.is_floating) continue;
            const pos = w.layout?.pos_in_scrolling_layout, c = pos ? pos[0] : 0, width = w.layout?.tile_size?.[0] ?? 0;
            if (!cols[c]) cols[c] = { index: c, width: width, focused: false, windowId: w.id, title: w.title ?? w.app_id ?? "" };
            cols[c].width = Math.max(cols[c].width, width);
            if (w.id === focusedWindowId) { cols[c].focused = true; cols[c].windowId = w.id; cols[c].title = w.title ?? w.app_id ?? ""; }
        }
        return Object.values(cols).sort((a, b) => a.index - b.index);
    }

    function action(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)); }
    function focusWorkspace(idx) { action(["focus-workspace", String(idx)]); }
    function focusWindow(id) { action(["focus-window", "--id", String(id)]); }
    function nextLayout() { action(["switch-layout", "next"]); }
    // A layout's name as two letters: "English (US)" is US, "German" is DE; anything unknown, its first two.
    readonly property var layoutCodes: ({ English: "EN", German: "DE", French: "FR", Spanish: "ES", Italian: "IT", Portuguese: "PT",
        Russian: "RU", Japanese: "JA", Korean: "KO", Chinese: "ZH", Arabic: "AR", Hebrew: "HE", Greek: "EL", Polish: "PL", Dutch: "NL",
        Swedish: "SV", Norwegian: "NO", Danish: "DA", Finnish: "FI", Turkish: "TR", Ukrainian: "UA", Czech: "CS", Hungarian: "HU",
        Romanian: "RO", Bulgarian: "BG", Serbian: "SR", Croatian: "HR", Slovak: "SK", Slovenian: "SL", Thai: "TH", Vietnamese: "VI",
        Hindi: "HI", Persian: "FA", Swahili: "SW", Icelandic: "IS", Estonian: "ET", Latvian: "LV", Lithuanian: "LT", Georgian: "KA", Armenian: "HY" })
    function layoutShort(name) {
        const n = String(name || "").trim(), uk = n.match(/^English \((US|UK)\)/);
        if (uk) return uk[1];
        const first = n.split(/[\s(]/)[0];
        return layoutCodes[first] ?? first.slice(0, 2).toUpperCase();
    }
    readonly property string layout: layouts[layoutIdx] ?? ""

    property Process stream: Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try { ev = JSON.parse(line); } catch (e) { return; }
                niri.connected = true;
                if (ev.WorkspacesChanged) niri.workspaces = ev.WorkspacesChanged.workspaces;
                else if (ev.WorkspaceActivated) {
                    const id = ev.WorkspaceActivated.id, focused = ev.WorkspaceActivated.focused;
                    const out = niri.workspaces.find(w => w.id === id)?.output;
                    niri.workspaces = niri.workspaces.map(w => Object.assign({}, w, {
                        is_active: w.output === out ? w.id === id : w.is_active,
                        is_focused: focused ? w.id === id : w.is_focused
                    }));
                }
                // The window a workspace shows as current changed (a new window, one closed, focus moved).
                else if (ev.WorkspaceActiveWindowChanged) {
                    const e = ev.WorkspaceActiveWindowChanged;
                    niri.workspaces = niri.workspaces.map(w => w.id === e.workspace_id ? Object.assign({}, w, { active_window_id: e.active_window_id }) : w);
                }
                else if (ev.WindowsChanged) {
                    niri.windows = ev.WindowsChanged.windows;
                    niri.focusedWindowId = niri.windows.find(w => w.is_focused)?.id ?? niri.focusedWindowId;
                }
                else if (ev.WindowOpenedOrChanged) {
                    const w = ev.WindowOpenedOrChanged.window;
                    niri.windows = niri.windows.filter(x => x.id !== w.id).concat([w]);
                    if (w.is_focused) niri.focusedWindowId = w.id;
                }
                else if (ev.WindowClosed) niri.windows = niri.windows.filter(x => x.id !== ev.WindowClosed.id);
                else if (ev.WindowFocusChanged) niri.focusedWindowId = ev.WindowFocusChanged.id ?? -1;
                else if (ev.WindowLayoutsChanged) {
                    const changes = new Map(ev.WindowLayoutsChanged.changes);
                    niri.windows = niri.windows.map(w => changes.has(w.id) ? Object.assign({}, w, { layout: changes.get(w.id) }) : w);
                }
                else if (ev.OverviewOpenedOrClosed) niri.overviewOpen = ev.OverviewOpenedOrClosed.is_open;
                else if (ev.ScreenshotCaptured) niri.screenshot(ev.ScreenshotCaptured.path ?? "");
                else if (ev.KeyboardLayoutsChanged) {
                    niri.layouts = ev.KeyboardLayoutsChanged.keyboard_layouts?.names ?? [];
                    niri.layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts?.current_idx ?? 0;
                }
                else if (ev.KeyboardLayoutSwitched) niri.layoutIdx = ev.KeyboardLayoutSwitched.idx ?? 0;
            }
        }
        onExited: { niri.connected = false; restart.restart(); }
    }
    // niri restarted, or its socket was not ready at login: reconnect.
    property Timer restart: Timer { interval: 1500; onTriggered: niri.stream.running = true }
}
