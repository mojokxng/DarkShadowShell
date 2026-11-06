import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    property var cfg: ({ widgets: {}, clock: {}, dock: {}, lock: {} })
    property string cfgText: ""
    property string wallpaper: ""          // the main monitor's (the widgets, the colors)
    property var walls: ({})                // monitor name -> its wallpaper (awww query)
    function wallOn(s) { return s && walls[s.name] ? walls[s.name] : wallpaper }
    property bool locked: false
    readonly property string home: Quickshell.env("HOME")
    // the screen the shell lives on (Settings > System > Screen > Main screen)
    // the widgets' screen (Settings > Monitors > Widgets on: the main one unless you chose another)
    readonly property var scr: Mon.widgetScreen
    readonly property int sw: scr ? scr.width : 1920
    readonly property int sh: scr ? scr.height : 1080
    readonly property string placement: cfg.clock && cfg.clock.placement ? cfg.clock.placement : "draggable"

    function wc(id) { return cfg.widgets && cfg.widgets[id] ? cfg.widgets[id] : ({}) }
    function on(id) { return wc(id).enabled === true }
    function savePos(id, x, y) {
        Quickshell.execDetached([home + "/.local/bin/desktop-set", "pos", id, String(x), String(y)])
    }

    // ---------------- widget editor ----------------
    readonly property bool editing: cfg.editing === true
    // what the editor offers; free = free width and height instead of scaling
    readonly property var catalog: [
        { id: "visualizer", name: "Visualizer", icon: "\udb85\udc7d", free: true,
          styles: [["bars", "Bars"], ["mirror", "Mirror"], ["wave", "Wave"], ["dots", "Dots"]],
          optKey: "color", opts: [["accent", "Theme color"], ["gradient", "Gradient"], ["rainbow", "Rainbow"], ["mono", "White / black"]], optDefault: "accent" },
        { id: "clock", name: "Clock", icon: "\uf017", styles: [["digital", "Digital"], ["line", "Line"], ["cookie", "Cookie"], ["pixel", "Pixel"]],
          optKey: "font", opts: [["default", "Font: Default"], ["bebas", "Bebas Neue"], ["orbitron", "Orbitron"], ["outfit", "Outfit"],
                                 ["grotesk", "Space Grotesk"], ["unbounded", "Unbounded"], ["shoulders", "Big Shoulders"]], optDefault: "default" },
        { id: "media", name: "Music", icon: "\uf001", card: true },
        { id: "weather", name: "Weather", icon: "\uf0c2", card: true },
        { id: "calendar", name: "Calendar", icon: "\uf073", card: true },
        { id: "usercard", name: "User", icon: "\uf007", card: true },
        { id: "resources", name: "CPU & RAM", icon: "\uf2db", card: true },
        { id: "battery", name: "Battery", icon: "\uf240", card: true },
        { id: "todo", name: "To-do", icon: "\uf14a", card: true },
        { id: "focus", name: "Focus", icon: "\uf017", card: true },
        { id: "notes", name: "Note", icon: "\uf249", card: true },
        { id: "gauge", name: "Gauge", icon: "\uf4bc", card: true,
          styles: [["water", "Water"], ["pentagon", "Pentagon"], ["cookie", "Cookie"], ["flower", "Flower"], ["clover", "Clover"], ["hexagon", "Hexagon"], ["sun", "Sun"], ["circle", "Circle"]],
          optKey: "metric", opts: [["cpu", "CPU"], ["ram", "RAM"], ["gpu", "GPU"], ["temp", "CPU heat"], ["battery", "Battery"]], optDefault: "cpu" },
        { id: "sky", name: "Sky", icon: "\uf0c2", card: true },
        { id: "nowring", name: "Now playing", icon: "\uf001", card: true },
        { id: "player", name: "Player", icon: "\uf144", card: true },
        { id: "playpill", name: "Play button", icon: "\uf04b", card: true },
        { id: "lyrics", name: "Lyrics", icon: "\uf075", card: true },
        { id: "storage", name: "Storage", icon: "\uf0a0", card: true },
        { id: "trio", name: "CPU · GPU · RAM", icon: "\uf2db", card: true },
        { id: "date", name: "Date", icon: "\uf073", card: true,
          styles: [["flower", "Flower"], ["cookie", "Cookie"], ["clover", "Clover"], ["sun", "Sun"], ["square", "Square"], ["circle", "Circle"]] }
    ]
    property var wins: ({})
    function reg(id, w) { const n = Object.assign({}, wins); n[id] = w; wins = n }
    function ds(args) { Quickshell.execDetached([home + "/.local/bin/desktop-set"].concat(args.map(function(a) { return String(a) }))) }
    function enabledOf(id) { return id === "clock" ? !!(cfg.clock && cfg.clock.enabled === true) : on(id) }
    function styleOf(id) {
        const w = wins[id]
        if (w && w.sty) return w.sty
        if (id !== "clock" && wc(id).style) return wc(id).style
        return id === "clock" ? (cfg.clock && cfg.clock.style ? cfg.clock.style : "digital") : (id === "visualizer" ? "bars" : (id === "gauge" ? "pentagon" : (id === "date" ? "flower" : "")))
    }
    // the second choice of a widget (visualizer color, clock font)
    function optOf(id, key, dflt) {
        const w = wins[id]
        if (id === "clock") return cfg.clock && cfg.clock[key] ? cfg.clock[key] : dflt
        if (w && key === "color" && w.vcolor) return w.vcolor
        return wc(id)[key] ? wc(id)[key] : dflt
    }
    function setOpt(id, key, v) {
        const w = wins[id]
        if (w && key === "color") w.vcolor = v
        patch(id, (function() { const o = {}; o[key] = v; return o })())
        wset(id, key, v)
    }
    // optimistic local change, the file follows a moment later
    function patch(id, obj) {
        const c = JSON.parse(JSON.stringify(cfg))
        if (id === "clock") c.clock = Object.assign(c.clock || {}, obj)
        else { c.widgets = c.widgets || {}; c.widgets[id] = Object.assign(c.widgets[id] || {}, obj) }
        cfg = c
    }
    function saveGeom(id) {
        const w = wins[id]
        if (!w) return
        const free = id === "visualizer"
        patch(id, free ? { x: Math.round(w.px), y: Math.round(w.py), w: Math.round(w.fw), h: Math.round(w.fh) }
                       : { x: Math.round(w.px), y: Math.round(w.py), scale: Math.round(w.sc * 1000) / 1000 })
        ds(["geom", id, Math.round(w.px), Math.round(w.py), free ? "-" : (Math.round(w.sc * 1000) / 1000), free ? Math.round(w.fw) : "-", free ? Math.round(w.fh) : "-"])
    }
    function wset(id, key, val) { ds(["wset", id, key, val]) }
    function setStyle(id, v) {
        const w = wins[id]
        if (w) w.sty = v
        if (id === "clock") { patch("clock", { style: v }); ds(["clock", "style", v]) }
        else { patch(id, { style: v }); wset(id, "style", v) }
    }
    function addWidget(id) {
        const w = wins[id]
        let geo = {}
        if (w && id !== "visualizer" && !(id === "clock" ? (cfg.clock && cfg.clock.x !== undefined) : (wc(id).x !== undefined))) {
            // a new widget lands in the middle of the screen
            geo = { x: Math.round((sw - w.dispW) / 2), y: Math.round((sh - w.dispH) / 2) }
        }
        if (id === "clock") { patch("clock", Object.assign({ enabled: true, placement: "draggable" }, geo)); ds(["clock", "enabled", "on"]) }
        else { patch(id, Object.assign({ enabled: true }, geo)); ds(["widget", id, "on"]) }
        if (geo.x !== undefined) ds(["geom", id, geo.x, geo.y])
    }
    function removeWidget(id) {
        if (id === "clock") { patch("clock", { enabled: false }); ds(["clock", "enabled", "off"]) }
        else { patch(id, { enabled: false }); ds(["widget", id, "off"]) }
    }
    function resetWidget(id) {
        const w = wins[id]
        ds(["reset-widget", id])
        if (w) { w.sc = 1; w.op = 1; w.bgv = 1; w.flp = false; w.px = w.defX; w.py = w.defY; w.fw = w.defW; w.fh = w.defH }
    }
    function resetAll() { ds(["reset-pos"]) }
    function finishEditing() { const c = JSON.parse(JSON.stringify(cfg)); c.editing = false; cfg = c; ds(["edit", "off"]) }

    Process {
        id: cfgProc
        // desktop.json, then "@@flat" while rice-effects has blur and transparency off
        command: ["bash", "-c", "cat \"$HOME/.config/rice/desktop.json\" 2>/dev/null; [ -e \"$HOME/.cache/rice/flat\" ] && printf '@@flat'; [ -e \"$HOME/.cache/rice/lite\" ] && printf '@@lite'; printf '@@accent'; sed -n 's/^@define-color accent *\\(#[0-9a-fA-F]\\{6\\}\\).*/\\1/p' \"$HOME/.config/waybar/colors.css\" 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fl = text.indexOf("@@flat") >= 0
                if (fl !== Look.flat) Look.flat = fl
                const lt = text.indexOf("@@lite") >= 0
                if (lt !== Look.lite) Look.lite = lt
                const ai = text.indexOf("@@accent")
                if (ai >= 0) {
                    const ac = text.substring(ai + 8).trim()
                    if (/^#[0-9a-fA-F]{6}$/.test(ac) && Look.accent.toString() !== ac.toLowerCase()) Look.accent = ac
                }
                const t = (ai >= 0 ? text.substring(0, ai) : text).replace("@@flat", "").replace("@@lite", "")
                if (t.trim().length === 0 || t === root.cfgText) return
                try {
                    const j = JSON.parse(t)
                    root.cfgText = t
                    root.cfg = j
                    Look.blur = j.widgetBlur !== false
                    Look.widgetAlpha = j.widgetOpacity !== undefined ? Math.max(0.2, Math.min(1, Number(j.widgetOpacity))) : 1
                    Look.theme = j.widgetTheme === "google" || j.widgetTheme === "outline" ? j.widgetTheme : "shadow"
                    Look.adapt = j.widgetAdapt !== false
                } catch (e) { }
            }
        }
    }
    // desktop.json is read as soon as it changes (no more starting a program 5 times a second to look at it);
    // the flags (flat, lite) and the accent color every 3 seconds
    Trigger { path: root.home + "/.config/rice/desktop.json"; every: 1500
        onContent: function(t) { if (!cfgProc.running) cfgProc.running = true } }
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: { if (!cfgProc.running) cfgProc.running = true }
    }

    // wavy progress (Settings > Appearance > Components keeps it in settings-app.json)
    Trigger {
        path: root.home + "/.config/rice/settings-app.json"
        every: 4000
        onContent: function(t) {
            let j = {}
            try { j = t.trim() !== "" ? JSON.parse(t) : {} } catch (e) { j = {} }
            Look.wavy = j.wavy !== false
            // the language from Settings > System > Languages
            Tr.lang = (typeof j.lang === "string" && /^[a-zA-Z-]{2,6}$/.test(j.lang)) ? j.lang : "en"
            if (typeof j.accentShape === "string" && j.accentShape !== "") Look.shape = j.accentShape
            Look.waveThick = j.progressThick !== undefined ? Math.max(2, Math.min(8, Number(j.progressThick))) : 4
        }
    }
    // shell shadows (rice-shadows)
    Trigger {
        path: root.home + "/.config/rice/shadows.json"
        every: 4000
        onContent: function(t) {
            let j = {}
            try { j = t.trim() !== "" ? JSON.parse(t) : {} } catch (e) { j = {} }
            Look.shadowsAll = j.enabled !== false
            Look.shadowBar = j.bar !== false
            Look.shadowPanels = j.panels !== false
            Look.shadowWidgets = j.widgets !== false
            Look.shadowNotif = j.notifications !== false
            Look.shadowSize = j.size !== undefined ? j.size : 18
            Look.shadowStrength = (j.strength !== undefined ? j.strength : 45) / 100
        }
    }

    Process {
        id: wpProc
        // one "<monitor>\t<picture>" line per monitor, then the last picked one (hyprquickpaper-current)
        command: ["bash", "-c", "awww query 2>/dev/null | sed -n 's/^[^:]*: *\\([^:]*\\): .*image: \\(.*\\)$/\\1\\t\\2/p'; printf '@@\\t'; cat \"$HOME/.cache/hyprquickpaper-current\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            const m = {}
            let last = ""
            for (const l of text.split("\n")) {
                const i = l.indexOf("\t")
                if (i < 0) continue
                const k = l.substring(0, i).trim(), v = l.substring(i + 1).trim()
                if (k === "@@") last = v; else if (v !== "") m[k] = v
            }
            if (JSON.stringify(m) !== JSON.stringify(root.walls)) root.walls = m
            const w = root.scr && m[root.scr.name] ? m[root.scr.name] : last
            if (w !== root.wallpaper) root.wallpaper = w
        } }
    }
    Timer {
        interval: 6000
        running: Look.adapt || Wm.niri || !!(root.placement !== "draggable" && root.cfg.clock && root.cfg.clock.enabled === true)
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!wpProc.running) wpProc.running = true }
    }

    Process {
        id: lockProc
        command: ["bash", "-c", "{ pgrep -x hyprlock >/dev/null || [ -e \"$HOME/.cache/rice/lock-active\" ]; } && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.locked = text.trim() === "1" }
    }
    Timer {
        interval: 2000
        running: !!(root.cfg.clock && root.cfg.clock.onlyLocked === true)
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!lockProc.running) lockProc.running = true }
    }

    // ---- auto-hide (Settings > Desktop): widgets fade out while windows are open on this screen
    readonly property bool autoHide: cfg.autoHide === true || Look.lite
    property bool busy: false
    readonly property bool hideWidgets: autoHide && busy && !editing && !locked
    Binding { target: Look; property: "covered"; value: root.busy && !root.editing && !root.locked }
    Process {
        id: busyProc
        command: ["bash", "-c", "exec \"$HOME/.local/bin/rice-busy\" \"$1\"", "_", root.scr ? root.scr.name : ""]
        // always on (it only listens to the window manager's events): auto-hide and the widgets' motion use it
        running: true
        stdout: SplitParser { onRead: function(line) { root.busy = line.trim() === "1" } }
        onRunningChanged: if (!running) root.busy = false
    }

    // ---- the desktop menu (right-click the desktop). Made before the widgets, so they stay on top of its catcher
    DeskMenu { editing: root.editing }

    // ---- clock
    WidgetWindow {
        id: clockWin
        wid: "clock"
        wc: root.placement === "draggable" ? (root.cfg.clock ? root.cfg.clock : ({})) : ({})
        draggable: root.placement === "draggable"
        editing: root.editing
        hidden: root.hideWidgets
        active: !!(root.cfg.clock && root.cfg.clock.enabled === true && (root.cfg.clock.onlyLocked !== true || root.locked || root.editing))
        bw: root.sw
        bh: root.sh
        cw: clk.natW
        ch: clk.natH
        // never moved: in the middle, a little above the center of the screen
        defX: root.placement === "draggable" || clk.fx < 0 ? Math.round((root.sw - cw) / 2) : Math.round(Math.max(30, Math.min(root.sw - cw - 30, clk.fx * root.sw - cw / 2)))
        defY: root.placement === "draggable" || clk.fy < 0 ? Math.round(root.sh * 0.23) : Math.round(Math.max(60, Math.min(root.sh - ch - 30, clk.fy * root.sh - ch / 2)))
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg("clock", clockWin)
        ClockWidget {
            id: clk
            anchors.fill: parent
            clockStyle: clockWin.sty !== "" ? clockWin.sty : (root.cfg.clock && root.cfg.clock.style ? root.cfg.clock.style : "digital")
            mode: root.placement
            wallpaper: root.wallpaper
            bw: root.sw
            bh: root.sh
            pal: clockWin.pal
            fontKey: root.cfg.clock && root.cfg.clock.font ? root.cfg.clock.font : "default"
        }
    }

    // ---- widgets (positions, sizes and looks come from the widget editor)
    WidgetWindow {
        id: weatherWin
        wid: "weather"; wc: root.wc("weather"); active: root.on("weather"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 300; ch: 120; defX: 40; defY: 370
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, weatherWin)
        WeatherWidget { anchors.fill: parent; pal: weatherWin.pal; running: root.on("weather") && !root.hideWidgets; bg: weatherWin.bgv }
    }
    WidgetWindow {
        id: mediaWin
        wid: "media"; wc: root.wc("media"); active: root.on("media"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 400; ch: 120; defX: root.sw - 440; defY: 60
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, mediaWin)
        MediaWidget { anchors.fill: parent; pal: mediaWin.pal; bg: mediaWin.bgv; running: root.on("media") && !root.hideWidgets }
    }
    WidgetWindow {
        id: calWin
        wid: "calendar"; wc: root.wc("calendar"); active: root.on("calendar"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 340; ch: 340; defX: root.sw - 380; defY: 200
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, calWin)
        CalendarWidget { anchors.fill: parent; pal: calWin.pal; bg: calWin.bgv }
    }
    WidgetWindow {
        id: userWin
        wid: "usercard"; wc: root.wc("usercard"); active: root.on("usercard"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 340; ch: 120; defX: root.sw - 380; defY: 560
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, userWin)
        UserCard { anchors.fill: parent; pal: userWin.pal; bg: userWin.bgv }
    }
    WidgetWindow {
        id: resWin
        wid: "resources"; wc: root.wc("resources"); active: root.on("resources"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 160; ch: 380; defX: 40; defY: root.sh - 440
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, resWin)
        ResourcesWidget { anchors.fill: parent; pal: resWin.pal; running: root.on("resources") && !root.hideWidgets; bg: resWin.bgv }
    }
    WidgetWindow {
        id: batWin
        wid: "battery"; wc: root.wc("battery"); active: root.on("battery"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 280; ch: 110; defX: 40; defY: 520
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, batWin)
        BatteryWidget { anchors.fill: parent; pal: batWin.pal; running: root.on("battery") && !root.hideWidgets; bg: batWin.bgv }
    }
    // to-do list, focus timer, note (click them to type)
    WidgetWindow {
        id: todoWin
        wid: "todo"; wc: root.wc("todo"); active: root.on("todo"); editing: root.editing; hidden: root.hideWidgets; keys: true; typing: todoW.typing
        bw: root.sw; bh: root.sh; cw: 330; ch: 390; defX: 440; defY: 200
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, todoWin)
        TodoWidget { id: todoW; anchors.fill: parent; pal: todoWin.pal; running: root.on("todo") && !root.hideWidgets; bg: todoWin.bgv }
    }
    WidgetWindow {
        id: focusWin
        wid: "focus"; wc: root.wc("focus"); active: root.on("focus"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 260; ch: 300; defX: 800; defY: 200
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, focusWin)
        FocusWidget {
            anchors.fill: parent; pal: focusWin.pal; bg: focusWin.bgv
            focusMin: root.wc("focus").focus !== undefined ? root.wc("focus").focus : 25
            onSetFocus: function(m) { root.patch("focus", { focus: m }); root.wset("focus", "focus", m) }
        }
    }
    WidgetWindow {
        id: notesWin
        wid: "notes"; wc: root.wc("notes"); active: root.on("notes"); editing: root.editing; hidden: root.hideWidgets; keys: true; typing: notesW.typing
        bw: root.sw; bh: root.sh; cw: 300; ch: 260; defX: 800; defY: 540
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, notesWin)
        NotesWidget { id: notesW; anchors.fill: parent; pal: notesWin.pal; bg: notesWin.bgv }
    }
    // audio visualizer: see-through, at the bottom of the screen by default, never takes clicks
    WidgetWindow {
        id: gaugeWin
        wid: "gauge"; wc: root.wc("gauge"); active: root.on("gauge"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 220; ch: 220; defX: 40; defY: 140
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, gaugeWin)
        GaugeWidget { anchors.fill: parent; pal: gaugeWin.pal; bg: gaugeWin.bgv; running: root.on("gauge") && !root.hideWidgets
            shape: gaugeWin.sty !== "" ? gaugeWin.sty : (root.wc("gauge").style || "pentagon")
            metric: root.optOf("gauge", "metric", "cpu") }
    }
    WidgetWindow {
        id: dateWin
        wid: "date"; wc: root.wc("date"); active: root.on("date"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 190; ch: 190; defX: 290; defY: 140
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, dateWin)
        DateWidget { anchors.fill: parent; pal: dateWin.pal; bg: dateWin.bgv; running: root.on("date") && !root.hideWidgets
            shape: dateWin.sty !== "" ? dateWin.sty : (root.wc("date").style || "flower") }
    }
    WidgetWindow {
        id: skyWin
        wid: "sky"; wc: root.wc("sky"); active: root.on("sky"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 220; ch: 220; defX: 40; defY: 60
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, skyWin)
        SkyWidget { anchors.fill: parent; pal: skyWin.pal; bg: skyWin.bgv; running: root.on("sky") && !root.hideWidgets }
    }
    WidgetWindow {
        id: nowringWin
        wid: "nowring"; wc: root.wc("nowring"); active: root.on("nowring"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 210; ch: 210; defX: 380; defY: 380
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, nowringWin)
        NowRingWidget { anchors.fill: parent; pal: nowringWin.pal; bg: nowringWin.bgv; running: root.on("nowring") && !root.hideWidgets }
    }
    WidgetWindow {
        id: playerWin
        wid: "player"; wc: root.wc("player"); active: root.on("player"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 320; ch: 380; defX: root.sw - 360; defY: root.sh - 470
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, playerWin)
        PlayerWidget { anchors.fill: parent; pal: playerWin.pal; bg: playerWin.bgv; running: root.on("player") && !root.hideWidgets }
    }
    WidgetWindow {
        id: playpillWin
        wid: "playpill"; wc: root.wc("playpill"); active: root.on("playpill"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 430; ch: 150; defX: 440; defY: root.sh - 240
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, playpillWin)
        PlayPillWidget { anchors.fill: parent; pal: playpillWin.pal; bg: playpillWin.bgv; running: root.on("playpill") && !root.hideWidgets }
    }
    WidgetWindow {
        id: lyricsWin
        wid: "lyrics"; wc: root.wc("lyrics"); active: root.on("lyrics"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 320; ch: 320; defX: 40; defY: root.sh - 420
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, lyricsWin)
        LyricsWidget { anchors.fill: parent; pal: lyricsWin.pal; bg: lyricsWin.bgv; running: root.on("lyrics") && !root.hideWidgets }
    }
    WidgetWindow {
        id: storageWin
        wid: "storage"; wc: root.wc("storage"); active: root.on("storage"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 330; ch: 76; defX: 660; defY: 440
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, storageWin)
        StorageWidget { anchors.fill: parent; pal: storageWin.pal; bg: storageWin.bgv; running: root.on("storage") && !root.hideWidgets }
    }
    WidgetWindow {
        id: trioWin
        wid: "trio"; wc: root.wc("trio"); active: root.on("trio"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 330; ch: 104; defX: 660; defY: 530
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, trioWin)
        TrioWidget { anchors.fill: parent; pal: trioWin.pal; bg: trioWin.bgv; running: root.on("trio") && !root.hideWidgets }
    }
    WidgetWindow {
        id: vizWin
        wid: "visualizer"; wc: root.wc("visualizer"); active: root.on("visualizer"); editing: root.editing; hidden: root.hideWidgets
        free: true; passive: true
        bw: root.sw; bh: root.sh
        defW: root.sw; defH: 180; defX: 0; defY: root.sh - 180
        Component.onCompleted: root.reg(wid, vizWin)
        VizWidget { anchors.fill: parent; running: root.on("visualizer") && !root.hideWidgets && !Look.lite && !Look.covered; style: vizWin.sty !== "" ? vizWin.sty : "bars"; flip: vizWin.flp; pal: vizWin.pal; colorMode: vizWin.vcolor !== "" ? vizWin.vcolor : "accent"
            nBars: Number(root.optOf("visualizer", "bars", 64)); shape: root.optOf("visualizer", "shape", "square"); spacing: root.optOf("visualizer", "gap", "normal")
            gain: Number(root.optOf("visualizer", "gain", "1.4")) }
    }

    // reads how bright the wallpaper is in each part of the screen, so every widget can pick dark or light text
    WallLum { path: root.wallpaper; sw: root.sw; sh: root.sh }
    // niri: the blurred wallpaper behind the workspaces in the overview (SUPER + Tab), each monitor its own
    Variants {
        model: Quickshell.screens
        NiriBackdrop { required property var modelData; screen: modelData; path: root.wallOn(modelData) }
    }

    EditorWindow { root: root }

    // ---- dashboard (middle of the bar edge, SUPER + W for wallpapers)
    Launcher { }
    WallPicker { walls: root.walls }
    // the bar on the left or right edge (Settings > DarkShadow bar > Position): on the main monitor only
    VBar { }
    // a bar on every monitor; the main monitor's one decides for the rest (the island takes the volume and the
    // notifications or not: that is the same setting for all of them)
    Variants {
        id: bars
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            readonly property alias bar: oneBar
            Bar { id: oneBar; screen: perScreen.modelData; nf: notifs }
            // a click on the desktop closes the bar's open card or tray menu (it lies under the windows, over the wallpaper)
            PanelWindow {
                screen: perScreen.modelData
                visible: oneBar.sticky
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "rice-island-catch"
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: oneBar.closeCards() }
            }
        }
    }
    readonly property var mainBar: {
        const l = bars.instances
        for (let i = 0; i < l.length; i++) if (l[i].bar.isMain) return l[i].bar
        return l.length > 0 ? l[0].bar : null
    }
    WifiMenu { }
    BluetoothMenu { }
    PowerMenu { }
    VolumeMenu { }
    VolumeOsd { islandTakes: !!root.mainBar && root.mainBar.islandVolume }
    GamePanel { gb: root.cfg.gamebar ? root.cfg.gamebar : ({}) }
    Notifs { id: notifs; islandTakes: !!root.mainBar && root.mainBar.islandNotifs && notifs.shellMode }
    ControlCenter { nf: notifs }

    Dock { dc: root.cfg.dock ? root.cfg.dock : ({}) }


}
