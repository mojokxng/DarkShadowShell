import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// SUPER + W: your wallpapers in a Material 3 sheet (it took the place of the dashboard's Wallpaper tab).
// Type to search, arrows and Enter to pick, Esc or a click outside to close; the shuffle button picks one at
// random. The one you have now wears a check in your shape. Thumbnails come from rice-dashboard walls.
PanelWindow {
    id: wp
    property bool open: false
    property real t: 0
    Behavior on t { NumberAnimation { duration: wp.open ? 520 : 160; easing.type: Easing.Linear } }
    function ease(p) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, p)), 4) }
    readonly property real et: Look.panelEase(t, outCurve)
    property bool outCurve: false            // Look.panelEase: a close that started fully open
    onTChanged: if (outCurve && (t < 0.001 || (open && t > 0.999))) outCurve = false
    onOpenChanged: {
        if (!open && t > 0.98) outCurve = true
        t = open ? 1 : 0
        if (open) { query = ""; search.text = ""; list.running = true; focusT.restart() }
    }
    NPal { id: pal; theme: "shell"; alpha: 0.94 }

    visible: open || (t > 0.01 && !closeT.done)
    // if the closing animation ever stalls (the compositor sent no frames for a moment), it still goes away
    Timer { id: closeT; property bool done: false; interval: 600; running: !open; onRunningChanged: if (running) done = false; onTriggered: done = true }
    // niri: blur behind the card (Hyprland blurs this layer with its own rule)
    NiriBlur { win: wp; items: [sheet]; radius: sheet.radius; on: wp.open && wp.t > 0.98 }
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-walls"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // opens on the monitor you are on, or the one whose bar you clicked (Mon.qml)
    Trigger { name: "walls-open"; onFired: function(l) { if (!wp.open) wp.screen = Mon.target(); wp.open = !wp.open } }

    // ---------- the wallpapers ----------
    property var all: []
    property string current: ""
    // more than one monitor: which one gets the picture ("" = all of them). The colors follow the main monitor
    // (Mon.qml), so a picture for another one keeps them as they are
    property string target: ""
    property var walls: ({})                    // monitor -> its picture now (shell.qml reads awww)
    property var picked: ({})                   // what was just set, until awww says so too
    onWallsChanged: picked = ({})
    readonly property bool mainTarget: target === "" || !Mon.main || target === Mon.main.name
    readonly property string cur: target === "" ? current : (picked[target] || walls[target] || current)
    function cycleTarget(d) {
        const l = [""].concat(Mon.names)
        target = l[(Math.max(0, l.indexOf(target)) + d + l.length) % l.length]
    }
    property string query: ""
    readonly property var shown: query === "" ? all : all.filter(function(w) { return w.name.toLowerCase().indexOf(wp.query.toLowerCase()) >= 0 })
    property int sel: 0
    // the list changed (you typed): the cards come in again, one after another
    property real ft: 1
    NumberAnimation { id: ftA; target: wp; property: "ft"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
    onQueryChanged: if (open) { ftA.restart(); grid.contentY = grid.originY }
    Process {
        id: list
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" walls"]
        stdout: StdioCollector { onStreamFinished: {
            try { const j = JSON.parse(text); wp.all = j.walls; wp.current = j.current } catch (e) { }
            for (let i = 0; i < wp.shown.length; i++) if (wp.shown[i].path === wp.cur) { wp.sel = i; grid.positionViewAtIndex(i, GridView.Center); break }
        } }
    }
    // thumbnails are made in the background the first time: look again a bit later
    Timer { interval: 4000; running: wp.open; repeat: true; onTriggered: if (!list.running && wp.all.some(function(w) { return w.thumb === w.path })) list.running = true }
    function apply(path) {
        if (mainTarget) current = path
        if (target !== "") { const n = Object.assign({}, picked); n[target] = path; picked = n }
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" wall \"$1\" \"$2\" \"$3\"", "_", path, target, mainTarget ? "" : "keep-colors"])
    }
    function shuffle() { if (shown.length > 0) { sel = Math.floor(Math.random() * shown.length); grid.positionViewAtIndex(sel, GridView.Contain); apply(shown[sel].path) } }
    onShownChanged: if (sel >= shown.length) sel = Math.max(0, shown.length - 1)
    Timer { id: focusT; interval: 60; onTriggered: search.forceActiveFocus() }

    // ---------- the scrim: a click outside closes ----------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32 * wp.et)
        MouseArea { anchors.fill: parent; onClicked: wp.open = false }
    }

    // ---------- the sheet ----------
    Shadow { anchors.fill: sheet; radius: sheet.radius; on: Look.shadows && Look.shadowPanels; opacity: sheet.opacity; size: Look.shadowSize; strength: Look.shadowStrength }
    Rectangle {
        id: sheet
        width: Math.min(parent.width - 80, 980); height: Math.min(parent.height - 120, 620)
        anchors.centerIn: parent
        radius: 32
        color: pal.surface
        opacity: Math.min(1, wp.et * 1.5)
        scale: 0.92 + 0.08 * wp.et
        transform: Translate { y: (1 - wp.et) * 30 }
        clip: true
        MouseArea { anchors.fill: parent }          // clicks on the sheet stay on it

        // header
        Item {
            id: head
            x: 24; y: 20; width: parent.width - 48; height: 48
            Item { id: hIc; width: 46; height: 46; anchors.verticalCenter: parent.verticalCenter
                Blob { anchors.fill: parent; kind: Look.shape; color: pal.container
                    SlowSpin { turn: 360; period: 30000; running: wp.open && !Look.lite } }
                MIcon { anchors.centerIn: parent; size: 22; filled: true; name: "wallpaper"; glyph: ""; color: pal.inkContainer } }
            Column {
                anchors.left: hIc.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                Text { text: "Wallpapers"; color: pal.fg; font.family: Fonts.main; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text { text: wp.shown.length + (wp.shown.length === 1 ? " wallpaper" : " wallpapers") + "  ·  "
                    + (wp.mainTarget ? "colors follow" : "colors stay with " + Mon.main.name); color: pal.dim; font.family: Fonts.main; font.pixelSize: 12 }
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                // search
                Rectangle {
                    width: 280; height: 44; radius: 22; color: pal.card
                    border.width: search.activeFocus ? 2 : 0; border.color: pal.primary
                    MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; size: 18; name: "search"; glyph: ""; color: pal.dim }
                    TextInput {
                        id: search
                        x: 42; width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter
                        color: pal.fg; font.family: Fonts.main; font.pixelSize: 14; clip: true
                        selectionColor: pal.primary; selectedTextColor: pal.inkPrimary
                        onTextChanged: { wp.query = text; wp.sel = 0 }
                        Text { visible: search.text === ""; text: "Search"; color: pal.dim; font: search.font }
                        Keys.onPressed: function(e) {
                            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
                            if (e.key === Qt.Key_Escape) { wp.open = false; e.accepted = true }
                            else if (e.key === Qt.Key_Tab && Mon.multi) { wp.cycleTarget(1); e.accepted = true }
                            else if (e.key === Qt.Key_Backtab && Mon.multi) { wp.cycleTarget(-1); e.accepted = true }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (wp.shown[wp.sel]) wp.apply(wp.shown[wp.sel].path); e.accepted = true }
                            else if (e.key === Qt.Key_Right) { wp.sel = Math.min(wp.shown.length - 1, wp.sel + 1); e.accepted = true }
                            else if (e.key === Qt.Key_Left) { wp.sel = Math.max(0, wp.sel - 1); e.accepted = true }
                            else if (e.key === Qt.Key_Down) { wp.sel = Math.min(wp.shown.length - 1, wp.sel + cols); e.accepted = true }
                            else if (e.key === Qt.Key_Up) { wp.sel = Math.max(0, wp.sel - cols); e.accepted = true }
                            if (e.accepted) { const y0 = grid.contentY; grid.positionViewAtIndex(wp.sel, GridView.Contain); const y1 = grid.contentY
                                if (y1 !== y0) { grid.contentY = y0; grid.scrollBy(y1 - y0) } }
                        }
                    }
                }
                IconBtn { icon: "shuffle"; filled: true; onHit: wp.shuffle() }
                IconBtn { icon: "close"; onHit: wp.open = false }
            }
        }

        // which monitor (only with more than one): Tab / Shift+Tab in the search field go through them
        Row {
            id: targets
            x: 24; y: 80
            visible: Mon.multi
            height: visible ? 34 : 0
            spacing: 8
            Repeater {
                model: [""].concat(Mon.names)
                delegate: Rectangle {
                    readonly property bool on: wp.target === modelData
                    width: chipT.implicitWidth + 32; height: 34; radius: on ? 12 : 17
                    Behavior on radius { NumberAnimation { duration: 200 } }
                    color: on ? pal.primary : (chipM.containsMouse ? pal.container : pal.card)
                    Text { id: chipT; anchors.centerIn: parent; font.family: Fonts.main; font.pixelSize: 13
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                        text: modelData === "" ? "All screens" : modelData + (Mon.main && Mon.main.name === modelData ? "  ·  main" : "")
                        color: parent.on ? pal.inkPrimary : (chipM.containsMouse ? pal.inkContainer : pal.fg) }
                    MouseArea { id: chipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { wp.target = modelData; search.forceActiveFocus() } }
                }
            }
        }

        // the grid
        GridView {
            id: grid
            x: 24; y: 88 + (targets.visible ? 44 : 0); width: parent.width - 48; height: parent.height - y - 20
            clip: true
            readonly property int cols: Math.max(2, Math.floor(width / 230))
            cellWidth: Math.floor(width / cols); cellHeight: Math.round(cellWidth * 0.68)
            model: wp.shown
            boundsBehavior: Flickable.StopAtBounds
            // the wheel: farther per notch, and it glides there (touchpads scroll as they are)
            property real goal: 0
            NumberAnimation { id: glide; target: grid; property: "contentY"; duration: 300; easing.type: Easing.OutCubic }
            function scrollBy(dy) {
                const top = grid.originY, bottom = Math.max(grid.originY, grid.contentHeight + grid.originY - grid.height)
                goal = Math.max(top, Math.min(bottom, (glide.running ? goal : contentY) + dy))
                glide.stop(); glide.from = contentY; glide.to = goal; glide.start()
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) {
                    if (e.pixelDelta.y !== 0) { glide.stop(); grid.contentY = Math.max(grid.originY, Math.min(Math.max(grid.originY, grid.contentHeight + grid.originY - grid.height), grid.contentY - e.pixelDelta.y * 2.2)) }
                    else grid.scrollBy(-e.angleDelta.y / 120 * grid.cellHeight * 1.6)
                }
            }
            delegate: Item {
                id: cell
                width: grid.cellWidth; height: grid.cellHeight
                readonly property bool cur: modelData.path === wp.cur
                readonly property bool picked: index === wp.sel
                // comes in one after another when the sheet opens, and again when what you type changes the list
                readonly property real it: wp.outCurve ? wp.et : Math.min(wp.ease((wp.t - Math.min(index, 18) * 0.025) / 0.55),
                                                    wp.ease((wp.ft - Math.min(index, 14) * 0.03) / 0.5))
                // while scrolling, the ones at the top and bottom edge are a little smaller and fainter
                readonly property real edge: {
                    const top = cell.y - grid.contentY, bot = top + cell.height
                    const out = Math.max(0, -top, bot - grid.height)
                    return Math.min(1, out / cell.height)
                }
                opacity: it * (1 - 0.55 * edge)
                scale: (0.94 + 0.06 * it) * (1 - 0.08 * edge)
                transform: Translate { y: (1 - cell.it) * 18 }
                Rectangle {
                    id: frame
                    anchors.fill: parent; anchors.margins: 6
                    radius: cell.cur ? 28 : 20
                    Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    color: pal.card
                    property real popS: 1
                    scale: popS * (cm.containsMouse || cell.picked ? 1.02 : 1)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    RoundImage { anchors.fill: parent; anchors.margins: cell.cur ? 4 : 0; cornerRadius: frame.radius - (cell.cur ? 4 : 0); source: "file://" + modelData.thumb }
                    Rectangle { anchors.fill: parent; radius: frame.radius; color: "transparent"
                        border.width: cell.cur ? 3 : (cell.picked ? 2 : 0); border.color: cell.cur ? pal.primary : Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.6) }
                    // the one you have: a check in your shape
                    Item { visible: scale > 0.01; scale: cell.cur ? 1 : 0; rotation: cell.cur ? 0 : -90
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        width: 30; height: 30; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                        Blob { anchors.fill: parent; kind: Look.shape; color: pal.primary }
                        MIcon { anchors.centerIn: parent; size: 16; filled: true; name: "check"; glyph: ""; color: pal.inkPrimary } }
                    // its name on hover
                    Rectangle {
                        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                        width: Math.min(parent.width - 20, nm.implicitWidth + 20); height: 26; radius: 13
                        color: Qt.rgba(0, 0, 0, 0.55)
                        opacity: cm.containsMouse || cell.picked ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Text { id: nm; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 20); elide: Text.ElideRight
                            text: modelData.name; color: "white"; font.family: Fonts.main; font.pixelSize: 11 }
                    }
                    // picking one: a ripple of your key color from where you clicked, and the card pops
                    Item {
                        anchors.fill: parent; clip: true
                        Rectangle {
                            id: rip
                            property real r: 0
                            property real cx: 0
                            property real cy: 0
                            x: cx - r; y: cy - r; width: 2 * r; height: 2 * r; radius: r
                            color: pal.primary; opacity: 0
                        }
                        ParallelAnimation {
                            id: ripA
                            NumberAnimation { target: rip; property: "r"; from: 0; to: frame.width * 1.2; duration: 620; easing.type: Easing.OutCubic }
                            NumberAnimation { target: rip; property: "opacity"; from: 0.45; to: 0; duration: 620; easing.type: Easing.InQuad }
                        }
                    }
                    SequentialAnimation {
                        id: pop
                        NumberAnimation { target: frame; property: "popS"; to: 0.93; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { target: frame; property: "popS"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: function(m) { rip.cx = m.x; rip.cy = m.y; ripA.restart(); pop.restart(); wp.sel = index; wp.apply(modelData.path) } }
                }
            }
            // nothing found / no wallpapers
            Text { anchors.centerIn: parent; visible: wp.shown.length === 0 && !list.running
                text: wp.all.length === 0 ? "No wallpapers yet" : "Nothing matches"; color: pal.dim; font.family: Fonts.main; font.pixelSize: 14 }
        }
    }

    component IconBtn: Item {
        id: ib
        property string icon: ""
        property bool filled: false
        signal hit()
        width: 44; height: 44
        Rectangle { anchors.fill: parent; radius: ibm.pressed ? 14 : 22; color: ib.filled ? pal.primary : pal.card
            Behavior on radius { NumberAnimation { duration: 200 } } }
        MIcon { anchors.centerIn: parent; size: 20; filled: true; name: ib.icon; glyph: ""; color: ib.filled ? pal.inkPrimary : pal.fg }
        MouseArea { id: ibm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ib.hit() }
    }
}
