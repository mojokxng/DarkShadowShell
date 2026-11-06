pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Which monitor each part of the shell goes on, when there is more than one.
//   main     the desktop widgets, the dock, the hot corner and the notifications: ~/.config/rice/screens.json
//            {"main": "DP-1"}, otherwise the left one (then the top one). When it is switched off, the next one.
//   focused  the monitor you work on (the one with the focused workspace): the launcher, the wallpapers, the
//            menus and the panels open there.
//   target() what a menu that is opening now should use: the bar you clicked it from (hint() just before), or
//            the focused monitor when it was a keybind.
// Every PanelWindow binds `screen` to one of these. A window without a screen is put on whatever was focused when
// it was made, and is lost for good if that monitor goes away (niri closes the surfaces of an output that is
// turned off, and Quickshell never makes an unbound one again).
Singleton {
    id: mon
    readonly property var screens: Quickshell.screens
    readonly property bool multi: screens.length > 1
    readonly property var names: {
        const l = []
        for (let i = 0; i < screens.length; i++) l.push(screens[i].name)
        return l
    }

    property string mainName: ""
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice/screens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); mon.mainName = j.main ? String(j.main) : "" } catch (e) { mon.mainName = "" } }
        onLoadFailed: mon.mainName = ""
    }

    function byName(n) {
        for (let i = 0; i < screens.length; i++) if (screens[i].name === n) return screens[i]
        return null
    }
    readonly property var main: {
        const s = byName(mainName)
        if (s) return s
        let best = null
        for (let i = 0; i < screens.length; i++) {
            const c = screens[i]
            if (!best || c.x < best.x || (c.x === best.x && c.y < best.y)) best = c
        }
        return best
    }
    readonly property var focused: byName(Wm.focusedOutput) || main

    property var hintScreen: null
    property real hintAt: 0
    function hint(s) { hintScreen = s; hintAt = Date.now() }
    function target() {
        if (hintScreen && Date.now() - hintAt < 2500)
            for (let i = 0; i < screens.length; i++) if (screens[i] === hintScreen) return hintScreen
        return focused
    }
}
