import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Effects

// What one screen of the lock screen shows, in the Material 3 look of the shell: your wallpaper (or what was on
// the screen) blurred and dimmed, the clock in one of four styles (one inside your shape), the day, a greeting
// with your picture in your shape, chips (weather, battery, notifications, CPU and RAM in wavy rings), the music
// with a wavy line, the password as shapes that pop in, and power buttons (Shut down in red).
FocusScope {
    id: lv
    property var root: LockCtx.root
    onRootChanged: console.log("[lock] the view has the lock state:", !!root)
    property var scr: null
    property bool isPreview: false
    readonly property var cfg: root ? root.cfg : ({})
    function v(k, d) { return cfg[k] !== undefined ? cfg[k] : d }
    // the first screen shows the music and reads the numbers (the others only the clock and the password)
    readonly property bool first: !scr || Quickshell.screens.length === 0 || scr === Quickshell.screens[0]
    readonly property bool atLeft: v("layout", "center") === "left"
    NPal { id: pal; theme: "shell"; alpha: 0.62 }

    // ---------- in and out ----------
    property real t: 0
    Component.onCompleted: { t = 1; keys.forceActiveFocus() }
    Behavior on t { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
    function ease(p) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, p)), 4) }
    function stg(i) { return ease((t - i * 0.06) / 0.62) }
    readonly property real gone: root ? root.out : 0

    // ---------- the time ----------
    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: lv.now = new Date() }
    function two(n) { return n < 10 ? "0" + n : "" + n }
    readonly property bool h24: v("clock_24h", true) !== false
    readonly property string hh: h24 ? two(now.getHours()) : String((now.getHours() + 11) % 12 + 1)
    readonly property string mm: two(now.getMinutes())
    readonly property var days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property string dateText: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()]
    readonly property var clockFonts: ({ bebas: "Bebas Neue", orbitron: "Orbitron", outfit: "Outfit", grotesk: "Space Grotesk",
                                         unbounded: "Unbounded", shoulders: "Big Shoulders Display" })
    readonly property string clockFont: {
        const f = clockFonts[v("clock_font", "default")]
        return f && Fonts.has(f) ? f : Fonts.numbers
    }
    readonly property color minuteColor: v("accent_clock", false) === true ? pal.primary : pal.fg

    // ---------- what the chips show ----------
    property string weather: ""
    property string notifs: ""
    property string greet: ""
    Process { running: lv.v("weather", false) === true; command: ["bash", "-c", "\"$HOME/.local/bin/rice-lock\" weather"]
        stdout: StdioCollector { onStreamFinished: lv.weather = text.trim() } }
    Process { id: nProc; running: lv.v("notifications", true) !== false; command: ["bash", "-c", "\"$HOME/.local/bin/rice-lock\" notif-count"]
        stdout: StdioCollector { onStreamFinished: lv.notifs = text.trim() } }
    Timer { interval: 15000; running: lv.v("notifications", true) !== false; repeat: true; onTriggered: if (!nProc.running) nProc.running = true }
    Process { running: lv.v("greeting", true) !== false; command: ["bash", "-c", "\"$HOME/.local/bin/rice-lock\" greet"]
        stdout: StdioCollector { onStreamFinished: lv.greet = text.trim() } }
    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: batt && batt.isPresent && batt.isLaptopBattery
    readonly property real battPct: batt ? batt.percentage : 0
    property var st: ({})
    Process {
        running: lv.v("resources", false) === true && lv.first
        command: ["bash", "-c", "exec \"$HOME/.local/bin/rice-dashboard\" stats"]
        stdout: SplitParser { onRead: function(l) { try { lv.st = JSON.parse(l) } catch (e) { } } }
    }
    Player { id: pl; running: lv.v("media", true) !== false }

    // ---------- the background ----------
    readonly property string bgKind: v("background", "screenshot")
    readonly property string bgPath: bgKind === "screenshot" && v("shot", "") !== "" ? v("shot", "") : v("wall", "")
    Rectangle { anchors.fill: parent; color: "#0b0c0e" }
    Image {
        id: bgImg
        anchors.fill: parent
        visible: false
        source: lv.bgKind !== "color" && lv.bgPath !== "" ? "file://" + lv.bgPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: Math.max(640, lv.width / 2)
    }
    MultiEffect {
        anchors.fill: parent
        source: bgImg
        visible: bgImg.status === Image.Ready
        blurEnabled: lv.v("blur", 3) > 0
        blur: Math.min(1, lv.v("blur", 3) / 4)
        blurMax: 64
        // the wallpaper comes in slowly, a little larger at first
        opacity: lv.ease(lv.t * 1.4) * (1 - lv.gone)
        scale: 1.06 - 0.06 * lv.ease(lv.t)
    }
    // a solid color background in your theme (Background: Color)
    Rectangle { anchors.fill: parent; visible: lv.bgKind === "color"
        gradient: Gradient { GradientStop { position: 0; color: Qt.darker(pal.container, 1.6) } GradientStop { position: 1; color: "#0b0c0e" } } }
    // darker, so the text stays readable (Dim)
    Rectangle { anchors.fill: parent; color: "black"; opacity: Math.max(0, Math.min(0.85, 1 - lv.v("dim", 0.5))) * 0.9 * (1 - lv.gone) }

    // ---------- the keyboard ----------
    // A real (hidden) text field takes what you type: it goes through Qt's whole input path (input methods such as
    // fcitx included), which plain key handlers miss on some setups. It keeps the focus whatever you click.
    TextInput {
        id: keys
        x: 0; y: 0; width: 1; height: 1
        clip: true
        focus: true
        color: "transparent"; selectionColor: "transparent"; selectedTextColor: "transparent"
        cursorVisible: false
        cursorDelegate: Item { }
        echoMode: TextInput.Password
        selectByMouse: false
        maximumLength: 256
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        readOnly: !lv.root || lv.root.phase === "checking" || lv.root.phase === "done"
        onTextChanged: {
            const r = lv.root
            if (!r) return
            if (!lv.anyKey && text !== "") { lv.anyKey = true; console.log("[lock] the keyboard works") }
            if (r.pass === text) return
            if (r.phase === "wrong") { r.phase = "idle"; r.msg = "" }
            r.pass = text
        }
        // what you type always goes at the end
        onCursorPositionChanged: if (cursorPosition !== text.length) cursorPosition = text.length
        Keys.onPressed: function(e) { lv.handleKey(e, "field") }
        onActiveFocusChanged: {
            console.log("[lock] password field focused:", activeFocus, "screen active:", lv.winActive)
            if (!activeFocus) refocus.restart()
        }
    }
    // the same password on every screen (and cleared after a wrong one)
    Connections {
        target: lv.root
        function onPassChanged() { if (keys.text !== lv.root.pass) keys.text = lv.root.pass }
    }
    // the screen may get the keyboard a moment after it shows: ask again for a few seconds, and after any click
    Timer { id: refocus; interval: 50; onTriggered: keys.forceActiveFocus() }
    // Quickshell moves this view into the real lock window only once the compositor has locked, and the focus can
    // get lost on the way: ask for it until the field has it (a cheap check, it stops as soon as it works)
    Timer { interval: 200; repeat: true; running: !keys.activeFocus; onTriggered: keys.forceActiveFocus() }
    readonly property var win: Window.window
    onWinChanged: {
        console.log("[lock] the view is in a window:", !!win)
        keys.forceActiveFocus(); refocus.restart()
    }
    function activate() {
        keys.forceActiveFocus()
        if (lv.win && !lv.isPreview) lv.win.requestActivate()
    }
    // keys that reach the view but not the field (no focus item yet): put them in the field anyway
    Keys.onPressed: function(e) { keys.forceActiveFocus(); lv.handleKey(e, "view") }

    // Every key is handled here (not left to the text field): some setups deliver keys whose text Qt does not
    // fill in, and the field then ignored them. The log says what kind of key came, never which one.
    property int logged: 0
    readonly property var digits: "0123456789"
    function handleKey(e, where) {
        const r = lv.root
        lv.anyKey = true
        const k = e.key
        let ch = ""
        if (e.text !== "" && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127) ch = e.text
        else if (!(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            // a key without text: letters and digits from the key itself
            if (k >= Qt.Key_A && k <= Qt.Key_Z) {
                ch = String.fromCharCode(97 + k - Qt.Key_A)
                if (e.modifiers & Qt.ShiftModifier) ch = ch.toUpperCase()
            } else if (k >= Qt.Key_0 && k <= Qt.Key_9 && !(e.modifiers & Qt.ShiftModifier)) ch = digits[k - Qt.Key_0]
            else if (k === Qt.Key_Space) ch = " "
        }
        if (lv.logged < 4) {
            lv.logged++
            console.log("[lock] key in the " + where + ": printable " + (ch !== "") + ", Qt gave text " + (e.text !== "")
                        + ", read-only " + keys.readOnly + ", typed so far " + keys.text.length)
        }
        if (!r) { e.accepted = true; return }
        if (k === Qt.Key_Escape) { if (lv.isPreview) Qt.quit(); else keys.text = "" }
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) r.submit()
        else if (k === Qt.Key_Backspace) { if (!keys.readOnly) keys.text = (e.modifiers & Qt.ControlModifier) ? "" : keys.text.slice(0, -1) }
        else if (ch !== "" && !keys.readOnly && keys.text.length < 256) keys.text = keys.text + ch
        e.accepted = true
    }
    onVisibleChanged: if (visible) keys.forceActiveFocus()
    // the compositor gives this screen the keyboard (Hyprland may do it a moment after the lock): take it at once
    readonly property bool winActive: Window.active
    onWinActiveChanged: { console.log("[lock] this screen has the keyboard:", winActive); if (winActive) keys.forceActiveFocus() }
    Connections { target: lv.root; ignoreUnknownSignals: true; function onSecureTickChanged() { lv.activate(); refocus.restart() } }
    property bool anyKey: false
    property bool clicked: false
    MouseArea {
        anchors.fill: parent
        onPressed: function(m) {
            if (!lv.clicked) { lv.clicked = true; console.log("[lock] mouse click; screen active:", lv.winActive, "field focused:", keys.activeFocus) }
            lv.activate(); m.accepted = false
        }
    }
    // after a while without a single key: offer hyprlock (the session stays locked while it takes over)
    property bool waited: false
    Timer { interval: 7000; running: !lv.isPreview && lv.first; onTriggered: lv.waited = true }

    // ---------- everything else (it leaves a little larger, as the session opens) ----------
    // One column in the middle of the screen: the day, the clock, the greeting, the chips, the password and the
    // music. It stays together and centred on every screen size (the clock gets smaller on small screens).
    readonly property real k: Math.max(0.62, Math.min(1.12, lv.height / 1000))
    Item {
        id: content
        anchors.fill: parent
        opacity: 1 - lv.gone
        scale: 1 + 0.04 * lv.gone

        Column {
            id: main
            width: Math.min(lv.width - 64, 600)
            x: lv.atLeft ? Math.round(lv.width * 0.08) : Math.round((lv.width - width) / 2)
            // centred, a little above the middle; it moves smoothly when the music comes or goes
            y: Math.max(24, Math.round((lv.height - height) / 2 - lv.height * 0.03))
            Behavior on y { enabled: lv.t >= 1; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Look.emph } }
            spacing: Math.round(16 * Math.min(1, lv.k))

            // the day
            Text {
                visible: lv.v("date", true) !== false
                anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                text: lv.dateText
                color: pal.fg; opacity: 0.9 * lv.stg(0)
                font.family: Fonts.main; font.pixelSize: Math.round(22 * Math.min(1, lv.k)); font.weight: Font.Medium
                transform: Translate { y: (1 - lv.stg(0)) * 20 }
            }

            // the clock
            Item {
                id: clock
                width: parent.width
                height: cl.height
                opacity: lv.stg(1)
                transform: Translate { y: (1 - lv.stg(1)) * 30 }
                readonly property string style: lv.v("clock", "big")
                readonly property real k: lv.k
                Item {
                    id: cl
                    width: parent.width
                    height: Math.round((clock.style === "shape" ? 290 : (clock.style === "stacked" ? 270 : (clock.style === "minimal" ? 96 : 176))) * clock.k)
                    // big: one line, very large
                    Row {
                        visible: clock.style === "big"
                        anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: lv.hh; color: pal.fg; font.family: lv.clockFont; font.pixelSize: Math.round(160 * clock.k); font.weight: Font.DemiBold }
                        Text { text: ":"; color: lv.minuteColor; opacity: lv.now.getSeconds() % 2 === 0 ? 1 : 0.35
                            font.family: lv.clockFont; font.pixelSize: Math.round(160 * clock.k); font.weight: Font.DemiBold
                            Behavior on opacity { NumberAnimation { duration: 300 } } }
                        Text { text: lv.mm; color: lv.minuteColor; font.family: lv.clockFont; font.pixelSize: Math.round(160 * clock.k); font.weight: Font.DemiBold }
                    }
                    // stacked: the hours over the minutes
                    Column {
                        visible: clock.style === "stacked"
                        anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(-34 * clock.k)
                        Text { anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter; text: lv.hh; color: pal.fg
                            font.family: lv.clockFont; font.pixelSize: Math.round(150 * clock.k); font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter; text: lv.mm
                            color: lv.v("accent_clock", false) === true ? pal.primary : Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.6)
                            font.family: lv.clockFont; font.pixelSize: Math.round(150 * clock.k); font.weight: Font.Bold }
                    }
                    // minimal: small and light
                    Text {
                        visible: clock.style === "minimal"
                        anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        text: lv.hh + ":" + lv.mm; color: pal.fg
                        font.family: lv.clockFont; font.pixelSize: Math.round(80 * clock.k); font.weight: Font.Light
                    }
                    // shape: the time inside your shape, which turns slowly
                    Item {
                        visible: clock.style === "shape"
                        width: Math.round(290 * clock.k); height: width
                        anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                        Blob { anchors.fill: parent; kind: Look.shape; color: pal.primary
                            RotationAnimator on rotation { from: 0; to: 360; duration: 60000; loops: Animation.Infinite; running: clock.style === "shape" } }
                        Column { anchors.centerIn: parent; spacing: Math.round(-22 * clock.k)
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: lv.hh; color: pal.inkPrimary
                                font.family: lv.clockFont; font.pixelSize: Math.round(100 * clock.k); font.weight: Font.Bold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: lv.mm; color: Qt.rgba(pal.inkPrimary.r, pal.inkPrimary.g, pal.inkPrimary.b, 0.7)
                                font.family: lv.clockFont; font.pixelSize: Math.round(100 * clock.k); font.weight: Font.Bold } }
                    }
                }
            }

            // a greeting with your picture in your shape
            Row {
                visible: lv.v("greeting", true) !== false || lv.v("avatar", true) !== false
                anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                spacing: 14
                opacity: lv.stg(2)
                transform: Translate { y: (1 - lv.stg(2)) * 26 }
                ShapeImage {
                    visible: lv.v("avatar", true) !== false
                    width: 48; height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    kind: Look.shape
                    source: lv.v("has_face", false) ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                    empty: pal.container; fallbackIcon: "person"; fallbackColor: pal.inkContainer
                }
                Text { visible: lv.v("greeting", true) !== false && lv.greet !== ""; anchors.verticalCenter: parent.verticalCenter; text: lv.greet
                    color: pal.fg; font.family: Fonts.main; font.pixelSize: 19; font.weight: Font.Medium }
            }

            // chips: weather, battery, notifications, CPU and RAM (they wrap onto two lines on narrow screens)
            Flow {
                id: chips
                visible: wchip.visible || bchip.visible || nchip.visible || cchip.visible || rchip.visible
                width: Math.min(lv.width - 64, implicitW)
                readonly property real implicitW: {
                    let w = 0, n = 0
                    for (const c of [wchip, bchip, nchip, cchip, rchip]) if (c.visible) { w += c.width; n++ }
                    return Math.ceil(w + Math.max(0, n - 1) * spacing) + 2
                }
                anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                spacing: 10
                opacity: lv.stg(3)
                transform: Translate { y: (1 - lv.stg(3)) * 24 }
                Chip { id: wchip; visible: lv.v("weather", false) === true && lv.weather !== ""; glyph: true
                    icon: lv.wGlyph(lv.weather); text: lv.weather }
                Chip { id: bchip; visible: lv.hasBatt; ring: lv.battPct; text: Math.round(lv.battPct * 100) + "%"
                    ringColor: lv.battPct <= 0.15 ? "#ff8a80" : pal.primary }
                Chip { id: nchip; visible: lv.v("notifications", true) !== false && lv.notifs !== "" && lv.notifs !== "0"; icon: "notifications"
                    text: lv.notifs + (lv.notifs === "1" ? " notification" : " notifications") }
                Chip { id: cchip; visible: lv.v("resources", false) === true && !!lv.st.cpu; ring: lv.st.cpu ? lv.st.cpu.usage / 100 : 0
                    text: "CPU " + (lv.st.cpu ? lv.st.cpu.usage : 0) + "%" }
                Chip { id: rchip; visible: lv.v("resources", false) === true && !!lv.st.mem; ring: lv.st.mem ? lv.st.mem.pct / 100 : 0
                    text: "RAM " + (lv.st.mem ? lv.st.mem.pct : 0) + "%" }
            }

            Item { width: 1; height: Math.round(14 * Math.min(1, lv.k)) }

            // ---------- the password ----------
            Item {
                id: passArea
                width: Math.min(parent.width, 380)
                height: 56 + 30                      // the field and, under it, the wave or the message
                anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                opacity: lv.stg(4)
                readonly property string style: lv.v("input", "pill")
                readonly property bool wrong: !!root && root.phase === "wrong"
                readonly property bool checking: !!root && root.phase === "checking"
                readonly property bool touch: checking && !!root && root.touch      // the security key is blinking
                // a little shake when the password is wrong
                property real shake: 0
                transform: Translate { x: passArea.shake; y: (1 - lv.stg(4)) * 24 }
                SequentialAnimation {
                    id: shakeA
                    NumberAnimation { target: passArea; property: "shake"; to: -14; duration: 50 }
                    NumberAnimation { target: passArea; property: "shake"; to: 12; duration: 70 }
                    NumberAnimation { target: passArea; property: "shake"; to: -8; duration: 70 }
                    NumberAnimation { target: passArea; property: "shake"; to: 5; duration: 60 }
                    NumberAnimation { target: passArea; property: "shake"; to: 0; duration: 60 }
                }
                onWrongChanged: if (wrong) shakeA.restart()

                Rectangle {
                    id: field
                    width: parent.width; height: 56
                    radius: passArea.style === "pill" ? height / 2 : (passArea.style === "box" ? 18 : 0)
                    color: passArea.style === "line" ? "transparent" : (passArea.wrong ? Qt.rgba(1, 0.42, 0.42, 0.18) : pal.surface)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    border.width: passArea.style === "line" ? 0 : (keys.activeFocus || passArea.checking || passArea.wrong ? 2 : 0)
                    border.color: passArea.wrong ? "#ff8a80" : pal.primary
                    Rectangle { visible: passArea.style === "line"; anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1
                        color: passArea.wrong ? "#ff8a80" : (keys.activeFocus ? pal.primary : Qt.rgba(1, 1, 1, 0.4)) }
                    // a lock in your shape
                    Item { id: lk; x: passArea.style === "line" ? 0 : 8; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40
                        Blob { anchors.fill: parent; kind: Look.shape; color: passArea.wrong ? "#ff8a80" : pal.primary
                            Behavior on color { ColorAnimation { duration: 200 } }
                            RotationAnimator on rotation { from: 0; to: 360; duration: 1600; loops: Animation.Infinite; running: passArea.checking } }
                        MIcon { anchors.centerIn: parent; size: 18; name: root && root.phase === "done" ? "lock_open" : (passArea.touch ? "key" : "lock")
                            glyph: passArea.touch ? String.fromCodePoint(0xF0306) : ""; color: pal.inkPrimary } }
                    // what you typed: full shapes in your accent that grow in slowly, turning a little as they
                    // settle (the Material 3 emphasized curve); while it checks they ripple like Google's loader
                    property real ripple: 0
                    NumberAnimation on ripple { from: 0; to: 1; duration: 1100; loops: Animation.Infinite; running: passArea.checking }
                    Row {
                        id: dots
                        anchors.left: lk.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Repeater {
                            model: root ? Math.max(0, Math.min(root.pass.length, Math.floor((passArea.width - 110) / 23))) : 0
                            delegate: Item {
                                id: dot
                                required property int index
                                width: 16; height: 16
                                property real p: 0
                                Component.onCompleted: p = 1
                                Behavior on p { NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Look.emph } }
                                // the wave while it checks: each one a moment after the one before
                                readonly property real bob: passArea.checking ? Math.sin(2 * Math.PI * (field.ripple - dot.index * 0.09)) : 0
                                Blob {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    kind: Look.shape
                                    color: passArea.wrong ? "#ff8a80" : pal.primary
                                    Behavior on color { ColorAnimation { duration: 260 } }
                                    scale: 0.2 + 0.8 * dot.p + (passArea.checking ? 0.12 * Math.max(0, dot.bob) : 0)
                                    opacity: Math.min(1, dot.p * 1.6) * (passArea.checking ? 0.65 + 0.35 * Math.max(0, dot.bob) : 1)
                                    rotation: -120 * (1 - dot.p)
                                    transform: Translate { y: (1 - dot.p) * 6 - (passArea.checking ? 3 * Math.max(0, dot.bob) : 0) }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.left: lk.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        visible: !!root && root.pass === ""
                        text: passArea.checking ? "Checking ..." : (lv.isPreview ? "Password (preview, Esc closes)" : "Enter your password")
                        color: pal.dim; font.family: Fonts.main; font.pixelSize: 15
                    }
                    // Enter, as a button too
                    Item {
                        anchors.right: parent.right; anchors.rightMargin: passArea.style === "line" ? 0 : 8; anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40
                        visible: !!root && root.pass !== "" && !passArea.checking
                        Rectangle { anchors.fill: parent; radius: 20; color: pal.primary; opacity: gom.containsMouse ? 1 : 0.85 }
                        MIcon { anchors.centerIn: parent; size: 20; name: "arrow_forward"; glyph: ""; color: pal.inkPrimary }
                        MouseArea { id: gom; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root) root.submit() }
                    }
                }
                // checking: a wave runs under the field
                WavyLine {
                    y: 56 + 10; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 40; height: 14
                    visible: passArea.checking && !passArea.touch
                    handle: false; moving: true; thick: 3
                    SequentialAnimation on value { running: passArea.checking; loops: Animation.Infinite
                        NumberAnimation { from: 0.15; to: 0.85; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.85; to: 0.15; duration: 700; easing.type: Easing.InOutSine } }
                    color: pal.primary; track: "transparent"
                }
                Text {
                    y: 56 + 10
                    width: parent.width
                    horizontalAlignment: lv.atLeft ? Text.AlignLeft : Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: !!root && root.msg !== "" && !passArea.checking
                    text: root ? root.msg : ""; color: "#ff8a80"; font.family: Fonts.main; font.pixelSize: 13
                }
                // the password was right and the key is blinking: say so (in place of the wave)
                Text {
                    y: 56 + 10
                    width: parent.width
                    horizontalAlignment: lv.atLeft ? Text.AlignLeft : Text.AlignHCenter
                    visible: passArea.touch
                    text: "Touch your security key"; color: pal.primary; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.Medium
                    SequentialAnimation on opacity { running: passArea.touch; loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine } }
                }
            }

            // ---------- the music ----------
            Rectangle {
                id: media
                visible: lv.v("media", true) !== false && pl.has && lv.first
                width: Math.min(parent.width, 420); height: 104; radius: 28
                anchors.horizontalCenter: lv.atLeft ? undefined : parent.horizontalCenter
                color: pal.surface
                opacity: lv.stg(5)
                transform: Translate { y: (1 - lv.stg(5)) * 30 }
                ShapeImage { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 80; height: 80; kind: Look.shape; source: pl.art
                    empty: pal.container; fallbackColor: pal.inkContainer
                    RotationAnimator on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: pl.playing } }
                Column {
                    x: 106; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 106 - 16; spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: pl.title; color: pal.fg; font.family: Fonts.main; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { width: parent.width; elide: Text.ElideRight; text: pl.artist; color: pal.dim; font.family: Fonts.main; font.pixelSize: 12 }
                    WavyLine { width: parent.width; height: 16; value: pl.frac; moving: pl.playing; seekable: true
                        color: pal.primary; track: pal.track; onMoved: function(v) { pl.seekTo(v) } }
                    Row {
                        spacing: 14
                        RoundBtn { icon: "skip_previous"; onHit: pl.prev() }
                        Item { width: 34; height: 34
                            Blob { anchors.fill: parent; kind: pl.playing ? Look.shape : "circle"; color: pal.primary
                                RotationAnimator on rotation { from: 0; to: 360; duration: 12000; loops: Animation.Infinite; running: pl.playing } }
                            MIcon { anchors.centerIn: parent; size: 18; name: pl.playing ? "pause" : "play_arrow"; glyph: ""; color: pal.inkPrimary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pl.toggle() } }
                        RoundBtn { icon: "skip_next"; onHit: pl.next() }
                    }
                }
            }
        }

        // ---------- the way out when the keyboard does not reach the lock screen ----------
        Rectangle {
            id: fb
            visible: !lv.isPreview && lv.first && !lv.anyKey && (lv.clicked || lv.waited) && lv.v("has_hyprlock", false) === true
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 32
            height: 52; radius: 26
            width: fbRow.implicitWidth + 36
            color: fbm.containsMouse ? pal.cardHi : pal.surface
            Behavior on color { ColorAnimation { duration: 160 } }
            Row { id: fbRow; anchors.centerIn: parent; spacing: 10
                MIcon { anchors.verticalCenter: parent.verticalCenter; size: 20; name: "keyboard"; glyph: ""; color: pal.primary }
                Column { anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Keyboard not working?"; color: pal.fg; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: "Switch to the classic lock (hyprlock)"; color: pal.dim; font.family: Fonts.main; font.pixelSize: 11 } } }
            MouseArea { id: fbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.root) lv.root.fallback() }
        }
        // rice-lock test: it unlocks itself
        Rectangle {
            visible: !!lv.root && lv.root.testMode === true && lv.first
            anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24
            height: 36; radius: 18; width: tst.implicitWidth + 32
            color: pal.primary
            Text { id: tst; anchors.centerIn: parent; color: pal.inkPrimary; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.DemiBold
                text: lv.root ? "Test: it unlocks itself in " + lv.root.testLeft + " s" : "" }
        }

        // ---------- power ----------
        Row {
            id: pwr
            visible: lv.v("power", true) !== false
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 32
            spacing: 12
            opacity: lv.stg(6)
            property string armed: ""
            Timer { id: disarm; interval: 3000; onTriggered: pwr.armed = "" }
            function act(k, cmd) {
                if (k !== "suspend" && armed !== k) { armed = k; disarm.restart(); return }
                armed = ""
                if (!lv.isPreview) Quickshell.execDetached(["bash", "-c", cmd])
            }
            Power { k: "suspend"; icon: "bedtime"; label: "Sleep"; onHit: pwr.act(k, "systemctl suspend") }
            Power { k: "reboot"; icon: "restart_alt"; label: "Restart"; onHit: pwr.act(k, "systemctl reboot") }
            Power { k: "poweroff"; icon: "power_settings_new"; label: "Shut down"; red: true; onHit: pwr.act(k, "systemctl poweroff") }
        }
    }

    function wGlyph(w) {
        const s = String(w).toLowerCase()
        if (s.indexOf("thunder") >= 0) return ""
        if (s.indexOf("snow") >= 0 || s.indexOf("sleet") >= 0) return ""
        if (s.indexOf("rain") >= 0 || s.indexOf("drizzle") >= 0 || s.indexOf("shower") >= 0) return ""
        if (s.indexOf("fog") >= 0 || s.indexOf("mist") >= 0) return ""
        if (s.indexOf("cloud") >= 0 || s.indexOf("overcast") >= 0) return ""
        return ""
    }

    // ---------- small parts ----------
    component Chip: Rectangle {
        id: ch
        property string text: ""
        property string icon: ""
        property bool glyph: false
        property real ring: -1
        property color ringColor: pal.primary
        height: 40; radius: 20
        width: row.implicitWidth + 28
        color: pal.surface
        Row {
            id: row
            anchors.centerIn: parent; spacing: 8
            Item { visible: ch.ring >= 0; width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                WavyArc { anchors.fill: parent; value: Math.max(0.02, ch.ring); thick: 3; wavy: false; color: ch.ringColor; track: pal.track } }
            MIcon { visible: ch.icon !== "" && !ch.glyph; anchors.verticalCenter: parent.verticalCenter; size: 17; name: ch.icon; glyph: ""; color: pal.primary }
            Text { visible: ch.glyph; anchors.verticalCenter: parent.verticalCenter; text: ch.icon; font.family: Fonts.icons; font.pixelSize: 15; color: pal.primary }
            Text { anchors.verticalCenter: parent.verticalCenter; text: ch.text; color: pal.fg; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.Medium }
        }
    }
    component RoundBtn: Item {
        id: rb
        property string icon: ""
        signal hit()
        width: 36; height: 36
        Rectangle { anchors.fill: parent; radius: 18; color: pal.fg; opacity: rbm.containsMouse ? 0.12 : 0 }
        MIcon { anchors.centerIn: parent; size: 18; name: rb.icon; glyph: ""; color: pal.fg }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.hit() }
    }
    component Power: Item {
        id: pw
        property string k: ""
        property string icon: ""
        property string label: ""
        property bool red: false
        signal hit()
        readonly property bool armed: parent && parent.armed === k
        width: armed ? lab.implicitWidth + 64 : 52; height: 52
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Look.emph } }
        Rectangle {
            anchors.fill: parent; radius: pwm.pressed ? 16 : 26
            Behavior on radius { NumberAnimation { duration: 180 } }
            color: pw.red ? Qt.rgba(1, 0.42, 0.42, pw.armed ? 0.9 : (pwm.containsMouse ? 0.32 : 0.2)) : (pw.armed ? pal.primary : (pwm.containsMouse ? pal.cardHi : pal.surface))
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Row { anchors.centerIn: parent; spacing: 8
            MIcon { anchors.verticalCenter: parent.verticalCenter; size: 20; name: pw.icon; glyph: ""
                color: pw.red ? (pw.armed ? "#3b0a0a" : "#ffb4ab") : (pw.armed ? pal.inkPrimary : pal.fg) }
            Text { id: lab; visible: pw.armed; anchors.verticalCenter: parent.verticalCenter; text: "Again: " + pw.label.toLowerCase()
                color: pw.red ? "#3b0a0a" : pal.inkPrimary; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.Medium } }
        MouseArea { id: pwm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pw.hit() }
    }
}
