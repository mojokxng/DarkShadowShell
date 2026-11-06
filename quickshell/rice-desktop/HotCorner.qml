import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Hot corner: touch the chosen screen corner and the panel slides out (Settings > Hot corners).
PanelWindow {
    screen: Mon.main               // Mon.qml
    id: hc
    property var cfg: ({ enabled: false })
    property var st: ({})
    property bool open: false
    property string cfgText: ""
    property string lastOpenCmd: ""
    property bool cmdSeen: false
    // after it closes while the pointer is still in the corner, wait until the pointer leaves the corner
    property bool armed: true
    property real t: 0

    readonly property real spd: cfg.speed ? cfg.speed : 1
    readonly property string corner: cfg.corner ? cfg.corner : "bottom-right"
    readonly property bool atBottom: corner.indexOf("bottom") === 0
    readonly property bool atRight: corner.indexOf("right") > 0
    readonly property string anim: cfg.animation ? cfg.animation : "grow"
    readonly property int gap: 10
    readonly property int trig: cfg.trigger ? cfg.trigger : 4
    // Settings > Hot corners > Size: the whole panel (text, icons, spacing) is drawn bigger or smaller
    readonly property real sc: cfg.scale ? Math.max(0.75, Math.min(1.5, cfg.scale)) : 1
    readonly property real pw: panel.width * sc
    readonly property real ph: panel.height * sc

    // emphasized decelerate in, emphasized accelerate out (Material 3 motion)
    NumberAnimation {
        id: tAnim
        target: hc
        property: "t"
    }
    function animateTo(v) {
        tAnim.stop()
        tAnim.to = v
        tAnim.duration = (v > 0.5 ? 520 : 300) / hc.spd
        tAnim.easing.type = Easing.BezierSpline
        tAnim.easing.bezierCurve = v > 0.5 ? [0.05, 0.7, 0.1, 1.0, 1, 1] : [0.3, 0.0, 0.8, 0.15, 1, 1]
        tAnim.start()
    }

    // panel surface: optional theme tint, transparency can be switched off
    function bgColor() {
        const a = hc.cfg.transparency === false ? 1 : (hc.cfg.opacity !== undefined ? hc.cfg.opacity : 0.9)
        let r = 18, g = 18, b = 20
        if (hc.cfg.tint === true && hc.st.accent) {
            const x = String(hc.st.accent).replace("#", "")
            r = 18 + (parseInt(x.substr(0, 2), 16) - 18) * 0.16
            g = 18 + (parseInt(x.substr(2, 2), 16) - 18) * 0.16
            b = 20 + (parseInt(x.substr(4, 2), 16) - 20) * 0.16
        }
        return Qt.rgba(r / 255, g / 255, b / 255, a)
    }
    function refresh() { if (!stateProc.running) stateProc.running = true }
    function run(cmd, arg, closeFirst) {
        if (closeFirst) hc.open = false
        const s = Object.assign({}, hc.st)
        if (cmd === "close") {
            return
        } else if (cmd === "allapps") {
            Quickshell.execDetached(["bash", "-c", "sleep 0.25; \"$HOME/.local/bin/rice-launch\""])
        } else if (cmd === "settings") {
            Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-settings\""])
        } else if (cmd === "wallpaper") {
            Quickshell.execDetached(["bash", "-c", "sleep 0.25; \"$HOME/.local/bin/rice-wallpaper\""])
        } else if (cmd === "lock") {
            Quickshell.execDetached(["bash", "-c", "sleep 0.3; setsid -f \"$HOME/.local/bin/rice-lock\" now >/dev/null 2>&1"])
        } else {
            // instant feedback, the real state follows a moment later
            if (cmd === "awake" || cmd === "wifi" || cmd === "bluetooth" || cmd === "dnd" || cmd === "gaming") s[cmd] = !s[cmd]
            if (cmd === "mic") s.mic_muted = !s.mic_muted
            if (cmd === "record" && arg === "stop") s.recording = false
            if (cmd === "wall") s.wall = arg
            if (cmd === "scheme") s.scheme = arg
            hc.st = s
            Quickshell.execDetached(["bash", "-c", "sleep \"$3\"; \"$HOME/.local/bin/rice-hotcorner\" \"$1\" \"$2\"", "_", cmd, arg, closeFirst ? "0.35" : "0"])
        }
        soon.restart()
        later.restart()
    }

    visible: cfg.enabled === true
    // niri: blur behind it (Hyprland blurs this layer with its own rule)
    NiriBlur { win: hc; items: [shape]; radius: shape.radius; on: hc.open && hc.t > 0.98 }
    color: "transparent"
    anchors { bottom: hc.atBottom; top: !hc.atBottom; right: hc.atRight; left: !hc.atRight }
    implicitWidth: pw + 2 * gap + 16
    implicitHeight: ph + 2 * gap + 16
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-hotcorner"
    WlrLayershell.keyboardFocus: hc.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // the corner itself always counts too, so resting the pointer there keeps the panel open
    // open: the whole corner area (the panel and the gap around it) keeps it open, so moving the pointer
    // along the screen edge next to the panel does not close it and open it again over and over
    mask: Region { item: (hc.open || hc.t > 0.02) ? area : trigger; Region { item: trigger } }
    Item {
        id: area
        anchors.fill: parent
        HoverHandler {
            id: areaHover
            enabled: hc.open
            onHoveredChanged: {
                if (hovered) { leaveTimer.stop(); graceTimer.stop() }
                else if (hc.open && !hover.hovered && !trigHover.hovered) leaveTimer.restart()
            }
        }
    }

    // ---- settings + "open now" requests
    Process {
        id: cfgProc
        command: ["bash", "-c", "cat \"$HOME/.config/rice/hotcorner.json\" 2>/dev/null || \"$HOME/.local/bin/rice-hotcorner\" config; echo; echo '@@'; cat \"$HOME/.cache/rice/hotcorner-open\" 2>/dev/null; echo '@@'; [ -e \"$HOME/.cache/rice/flat\" ] && echo flat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("@@")
                const c = p[0].trim()
                // blur & transparency off (rice-effects: Lite or gaming mode): a solid panel
                const fl = p.length > 2 && p[2].trim() === "flat"
                if (c.length > 0 && c + fl !== hc.cfgText) {
                    try { const j = JSON.parse(c); if (fl) { j.transparency = false; j.blur = false } hc.cfg = j; hc.cfgText = c + fl } catch (e) { }
                }
                const o = p.length > 1 ? p[1].trim() : ""
                if (hc.cmdSeen && o.length > 0 && o !== hc.lastOpenCmd) hc.open = true
                hc.lastOpenCmd = o
                hc.cmdSeen = true
            }
        }
    }
    Timer { interval: 400; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!cfgProc.running) cfgProc.running = true }

    // ---- live status while open
    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" state"]
        stdout: StdioCollector { onStreamFinished: { try { hc.st = JSON.parse(text) } catch (e) { } } }
    }
    Timer { interval: 1500; running: hc.open; repeat: true; triggeredOnStart: true; onTriggered: hc.refresh() }
    Timer { id: soon; interval: 450; onTriggered: hc.refresh() }
    Timer { id: later; interval: 1600; onTriggered: hc.refresh() }

    // ---- corner trigger
    Item {
        id: trigger
        width: hc.trig
        height: hc.trig
        x: hc.atRight ? parent.width - width : 0
        y: hc.atBottom ? parent.height - height : 0
        HoverHandler {
            id: trigHover
            onHoveredChanged: { if (hovered) { leaveTimer.stop(); graceTimer.stop() } else if (hc.open && !hover.hovered) leaveTimer.restart() }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (hc.armed && !hc.open) openTimer.restart()
            onExited: { openTimer.stop(); hc.armed = true }
            onClicked: hc.open = !hc.open
        }
    }
    Timer { id: openTimer; interval: Math.max(1, hc.cfg.delay !== undefined ? hc.cfg.delay : 150); onTriggered: hc.open = true }

    // ---- close when the pointer leaves
    Timer {
        id: leaveTimer
        interval: 380
        onTriggered: if (hc.cfg.close_on_leave !== false && !hover.hovered && !trigHover.hovered && !areaHover.hovered) shotCheck.running = true
    }
    // a screenshot (Print) is being taken while the panel is open: stay, so the panel can be in the picture
    Process {
        id: shotCheck
        command: ["bash", "-c", "[ -e \"$HOME/.cache/rice/shooting\" ] && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "1") { shotWait.restart(); return }
                if (!hover.hovered && !trigHover.hovered && !areaHover.hovered) hc.open = false
            }
        }
    }
    Timer { id: shotWait; interval: 400; onTriggered: if (hc.open && !hover.hovered && !trigHover.hovered && !areaHover.hovered) shotCheck.running = true }
    Timer {
        // opened but the pointer never came into the panel
        id: graceTimer
        interval: 1400
        onTriggered: if (hc.cfg.close_on_leave !== false && !hover.hovered && !trigHover.hovered && !areaHover.hovered) hc.open = false
    }
    onOpenChanged: {
        animateTo(open ? 1 : 0)
        if (open) { refresh(); graceTimer.restart() }
        else { graceTimer.stop(); leaveTimer.stop() }
    }

    Item {
        id: holder
        readonly property bool grow: hc.anim === "grow"
        width: grow ? hc.pw * (0.62 + 0.38 * hc.t) : hc.pw
        height: grow ? Math.max(1, hc.ph * hc.t) : hc.ph
        x: (hc.atRight ? parent.width - width - hc.gap : hc.gap)
           + (hc.anim === "slide" ? (1 - hc.t) * (hc.atRight ? hc.pw + hc.gap + 4 : -(hc.pw + hc.gap + 4)) : 0)
        y: hc.atBottom ? parent.height - height - hc.gap : hc.gap
        visible: hc.t > 0.005
        clip: grow
        opacity: hc.anim === "fade" ? hc.t : (hc.anim === "scale" ? Math.min(1, hc.t * 3) : 1)
        transform: Scale {
            origin.x: hc.atRight ? holder.width : 0
            origin.y: hc.atBottom ? holder.height : 0
            xScale: hc.anim === "scale" ? 0.82 + 0.18 * hc.t : 1
            yScale: hc.anim === "scale" ? 0.82 + 0.18 * hc.t : 1
        }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { leaveTimer.stop(); graceTimer.stop() }
                else if (hc.open) leaveTimer.restart()
            }
        }

        // the shape that grows (rounded even while it is small)
        Rectangle {
            id: shape
            anchors.fill: parent
            radius: Math.min(panel.rad * hc.sc, Math.min(width, height) / 2)
            color: hc.bgColor()
            antialiasing: true
        }
        // one thin, even outline that follows the rounded corners exactly (drawn on top of the fill,
        // so it never doubles up with the background at the corners)
        Rectangle {
            anchors.fill: shape
            radius: shape.radius
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)
            z: 2
        }
        // soft light on the top edge only
        Rectangle {
            x: shape.radius; width: shape.width - 2 * shape.radius
            y: 0; height: 1
            z: 2
            visible: !hc.atBottom || hc.anim !== "grow" || hc.t > 0.9
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.14) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        HotCornerPanel {
            id: panel
            showBg: false
            cfg: hc.cfg
            st: hc.st
            open: hc.open
            // content stays pinned to the corner while the shape reveals it
            transformOrigin: Item.TopLeft
            scale: hc.sc
            x: hc.atRight ? holder.width - hc.pw : 0
            y: hc.atBottom ? holder.height - hc.ph : 0
            onAct: function(cmd, arg, closeFirst) { hc.run(cmd, arg, closeFirst) }
            onLaunch: function(entry) { hc.open = false; entry.execute() }
        }
    }

    SfxTap { visible: hc.open }
}
