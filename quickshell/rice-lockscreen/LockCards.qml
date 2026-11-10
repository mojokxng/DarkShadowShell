import Quickshell
import Quickshell.Io
import QtQuick

// The "Cards" lock screen: tall cards in the middle (the month, the time, the music) tinted with your theme, and a
// slim bar at the bottom with the battery, the keyboard layout, the password and the power buttons.
// Locking (SUPER + L): the cards rise one after another with a slight turn while the wallpaper blurs in.
// The password: every key drops in a shape with a ring around it; a wrong one shakes and the shapes fall away;
// the right one turns the lock open and everything lifts off.
Item {
    id: lc
    property var lv: null
    property var pal: null
    readonly property var root: lv ? lv.root : null
    readonly property real t: lv ? lv.t : 1
    readonly property real gone: lv ? lv.gone : 0
    function stg(i) { return lv ? lv.stg(i) : 1 }
    readonly property real k: Math.max(0.7, Math.min(1.15, height / 1000))
    readonly property color acc: pal ? pal.primary : "#9ec9bd"
    readonly property color ink: pal ? pal.inkPrimary : "#10201c"
    readonly property color fg: pal ? pal.fg : "white"
    readonly property color dim: pal ? pal.dim : "#aaa"
    readonly property var now: lv ? lv.now : new Date()

    // ---------- the keyboard layout (a click switches it) ----------
    property string layout: ""
    Process {
        id: kbP
        running: true
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" kbd-state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); lc.layout = j.active || (j.layouts && j.layouts[0]) || "" } catch (e) { } } }
    }
    function shortLay(s) {
        const m = { "English (US)": "US", "English (UK)": "UK", "Polish": "PL", "German": "DE", "French": "FR", "Spanish": "ES", "Italian": "IT",
                    "Russian": "RU", "Ukrainian": "UA", "Czech": "CZ", "Portuguese": "PT", "Portuguese (Brazil)": "BR", "Dutch": "NL" }
        if (m[s]) return m[s]
        return s.length <= 4 ? s.toUpperCase() : s.slice(0, 2).toUpperCase()
    }

    // ---------- the cards ----------
    readonly property real cw: Math.round(250 * k)
    readonly property real ch: Math.round(500 * k)
    readonly property bool music: lv && lv.v("media", true) !== false && lv.first && !!pl && pl.has
    readonly property var pl: lv ? lv.player : null

    Row {
        id: cardsRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((lc.height - lc.ch) / 2 - lc.height * 0.04) - 40 * lc.gone
        spacing: Math.round(18 * lc.k)
        opacity: 1 - lc.gone
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        // --- the month ---
        Card {
            idx: 0
            Text {
                x: 22; y: 10
                text: Tr.loc.standaloneMonthName(lc.now.getMonth(), Locale.ShortFormat).replace(".", "").toUpperCase()
                color: lc.acc
                font.family: lv ? lv.clockFont : Fonts.numbers; font.pixelSize: Math.round(96 * lc.k); font.weight: Font.Black
                width: parent.width - 30; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 40
            }
            Column {
                x: 24; y: Math.round(130 * lc.k); spacing: 2
                Text { text: Tr.day(lc.now.getDay()) + " " + lc.now.getDate()
                    color: lc.fg; font.family: Fonts.main; font.pixelSize: Math.round(21 * lc.k); font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                Text { text: lc.now.getFullYear() + "  ·  " + Tr.t("week ") + lc.week(lc.now)
                    color: lc.dim; font.family: Fonts.main; font.pixelSize: Math.round(12 * lc.k); font.letterSpacing: 1 }
            }
            // the month grid, today in your shape
            Grid {
                id: mg
                x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                columns: 7; rowSpacing: Math.round(6 * lc.k); columnSpacing: 0
                readonly property real cellW: (parent.width - 32) / 7
                Repeater {
                    model: 7
                    Text { width: mg.cellW; horizontalAlignment: Text.AlignHCenter; text: Tr.week(false)[index]
                        color: lc.dim; opacity: 0.7; font.family: Fonts.main; font.pixelSize: Math.round(10 * lc.k) }
                }
                Repeater {
                    model: lc.cells
                    delegate: Item {
                        width: mg.cellW; height: Math.round(26 * lc.k)
                        readonly property bool today: modelData === lc.now.getDate()
                        Blob { anchors.centerIn: parent; visible: parent.today; width: Math.round(28 * lc.k); height: width; kind: "cookie"; color: lc.acc
                            RotationAnimator on rotation { from: 0; to: 360; duration: 30000; loops: Animation.Infinite; running: parent.visible } }
                        Text { anchors.centerIn: parent; text: modelData > 0 ? modelData : ""; color: parent.today ? lc.ink : lc.fg
                            opacity: parent.today ? 1 : 0.85; font.family: Fonts.numbers; font.pixelSize: Math.round(12 * lc.k); font.weight: parent.today ? Font.Bold : Font.Medium }
                    }
                }
            }
        }

        // --- the time ---
        Card {
            idx: 1
            // the hours over the minutes, very large; the minutes in your color
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(40 * lc.k)
                spacing: Math.round(-62 * lc.k)
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: lv ? lv.hh : ""; color: lc.fg
                    font.family: lv ? lv.clockFont : Fonts.numbers; font.pixelSize: Math.round(150 * lc.k); font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: lv ? lv.mm : ""; color: lc.acc
                    font.family: lv ? lv.clockFont : Fonts.numbers; font.pixelSize: Math.round(150 * lc.k); font.weight: Font.Bold }
            }
            // the seconds go round your shape
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(28 * lc.k)
                width: Math.round(120 * lc.k); height: width
                Blob { anchors.fill: parent; kind: Look.shape; color: Qt.rgba(lc.acc.r, lc.acc.g, lc.acc.b, 0.16)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 60000; loops: Animation.Infinite; running: lc.visible } }
                WavyArc { anchors.fill: parent; anchors.margins: 10; value: Math.max(0.01, lc.now.getSeconds() / 60); thick: 4; wavy: true
                    color: lc.acc; track: Qt.rgba(1, 1, 1, 0.08) }
                Column { anchors.centerIn: parent; spacing: 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: lc.now.getSeconds() < 10 ? "0" + lc.now.getSeconds() : lc.now.getSeconds()
                        color: lc.acc; font.family: Fonts.numbers; font.pixelSize: Math.round(26 * lc.k); font.weight: Font.Bold }
                }
            }
        }

        // --- the music ---
        Card {
            idx: 2
            visible: lc.music
            // the cover fills the lower part, under a soft curve
            ShapeImage {
                id: art
                x: 10; y: Math.round(parent.height * 0.36); width: parent.width - 20; height: parent.height - y - 84
                kind: "square"; source: pl.art; empty: Qt.rgba(1, 1, 1, 0.06); fallbackColor: lc.dim
                opacity: 0.95
            }
            Text {
                x: 22; y: 16; width: parent.width - 40
                text: pl.title; color: lc.fg; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                font.family: Fonts.main; font.pixelSize: Math.round(30 * lc.k); font.weight: Font.Black; lineHeight: 0.9
            }
            Rectangle {
                x: 20; y: Math.round(parent.height * 0.36) - height - 14
                height: 26; radius: 13; width: Math.min(parent.width - 40, art2.implicitWidth + 22)
                color: lc.acc
                Text { id: art2; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 22); elide: Text.ElideRight
                    text: pl.artist; color: lc.ink; font.family: Fonts.main; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
            WavyLine { x: 20; width: parent.width - 40; height: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 66
                value: pl.frac; moving: pl.playing; seekable: true; color: lc.acc; track: Qt.rgba(1, 1, 1, 0.12); onMoved: function(v) { pl.seekTo(v) } }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                spacing: 8
                Pill2 { w: 54; icon: "skip_previous"; onHit: pl.prev() }
                Pill2 { w: 70; icon: pl.playing ? "pause" : "play_arrow"; strong: true; onHit: pl.toggle() }
                Pill2 { w: 54; icon: "skip_next"; onHit: pl.next() }
            }
        }
    }

    // ---------- the bar at the bottom ----------
    Row {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(34 * lc.k)
        spacing: 10
        opacity: lc.stg(4) * (1 - lc.gone)
        transform: Translate { y: (1 - lc.stg(4)) * 60 + lc.gone * 30 }

        // battery and the layout
        Rectangle {
            height: 52; radius: 26; width: left.implicitWidth + 16
            color: lc.pal ? lc.pal.surface : "#222"
            Row {
                id: left
                anchors.centerIn: parent; spacing: 6
                Rectangle { visible: lv && lv.hasBatt; height: 38; radius: 19; width: bt.implicitWidth + 24; color: Qt.rgba(1, 1, 1, 0.06)
                    Row { id: bt; anchors.centerIn: parent; spacing: 6
                        Item { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                            WavyArc { anchors.fill: parent; value: lv ? Math.max(0.02, lv.battPct) : 0; thick: 3; wavy: false; color: lv && lv.battPct <= 0.15 ? "#ff8a80" : lc.acc; track: Qt.rgba(1, 1, 1, 0.1) } }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: lv ? Math.round(lv.battPct * 100) + "%" : ""; color: lc.fg; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.Medium } } }
                Rectangle { visible: lc.layout !== ""; height: 38; radius: 19; width: lay.implicitWidth + 24; color: lm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Row { id: lay; anchors.centerIn: parent; spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; size: 17; name: "keyboard"; glyph: ""; color: lc.acc }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: lc.shortLay(lc.layout); color: lc.fg; font.family: Fonts.main; font.pixelSize: 13; font.weight: Font.DemiBold } }
                    MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/hypr-set\" kbd-next"]); relay.restart() } }
                    Timer { id: relay; interval: 250; onTriggered: kbP.running = true } }
            }
        }

        // the password
        Rectangle {
            id: pass
            readonly property bool wrong: !!lc.root && lc.root.phase === "wrong"
            readonly property bool checking: !!lc.root && lc.root.phase === "checking"
            readonly property bool done: !!lc.root && lc.root.phase === "done"
            // the password was right and the security key (pam_u2f) is blinking: say so in place of the shapes
            readonly property bool touch: checking && !!lc.root && lc.root.touch === true
            height: 52; radius: 26
            width: Math.round(400 * Math.min(1, lc.k)) + (done ? 60 : 0)
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
            color: wrong ? Qt.rgba(1, 0.42, 0.42, 0.22) : (lc.pal ? lc.pal.surface : "#222")
            Behavior on color { ColorAnimation { duration: 200 } }
            border.width: lv && lv.focusOk ? 2 : 0
            border.color: wrong ? "#ff8a80" : lc.acc
            property real shake: 0
            transform: Translate { x: pass.shake }
            SequentialAnimation {
                id: shakeA
                NumberAnimation { target: pass; property: "shake"; to: -16; duration: 45 }
                NumberAnimation { target: pass; property: "shake"; to: 14; duration: 65 }
                NumberAnimation { target: pass; property: "shake"; to: -10; duration: 65 }
                NumberAnimation { target: pass; property: "shake"; to: 6; duration: 55 }
                NumberAnimation { target: pass; property: "shake"; to: 0; duration: 55 }
            }
            onWrongChanged: if (wrong) { shakeA.restart(); fallen.restart() }
            // a wrong password: the shapes that were there fall away
            property int lostN: 0
            property real fall: 0
            NumberAnimation { id: fallen; target: pass; property: "fall"; from: 0; to: 1; duration: 700; easing.type: Easing.InQuad }

            Item { id: lk; x: 7; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 38
                Blob { anchors.fill: parent; kind: Look.shape; color: pass.wrong ? "#ff8a80" : lc.acc
                    Behavior on color { ColorAnimation { duration: 200 } }
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1400; loops: Animation.Infinite; running: pass.checking } }
                MIcon { anchors.centerIn: parent; size: 18; name: pass.done ? "lock_open" : (pass.touch ? "key" : "lock")
                    glyph: pass.touch ? String.fromCodePoint(0xF0306) : ""; color: lc.ink
                    scale: pass.done ? 1.25 : 1; Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } } } }
            property real ripple: 0
            NumberAnimation on ripple { from: 0; to: 1; duration: 1000; loops: Animation.Infinite; running: pass.checking }
            Row {
                anchors.left: lk.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: !pass.touch
                Repeater {
                    model: lc.root ? Math.max(0, Math.min(lc.root.pass.length, Math.floor((pass.width - 110) / 20))) : 0
                    delegate: Item {
                        id: dot
                        required property int index
                        width: 14; height: 14
                        property real p: 0
                        Component.onCompleted: { p = 0; popA.start(); ringA.start() }
                        NumberAnimation { id: popA; target: dot; property: "p"; from: 0; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                        readonly property real bob: pass.checking ? Math.sin(2 * Math.PI * (pass.ripple - dot.index * 0.1)) : 0
                        // a ring that opens around a new shape and fades
                        Rectangle {
                            id: ring
                            anchors.centerIn: parent
                            property real r: 0
                            width: 14 + 22 * r; height: width; radius: width / 2
                            color: "transparent"; border.width: 2; border.color: lc.acc
                            opacity: (1 - r) * 0.8
                            NumberAnimation { id: ringA; target: ring; property: "r"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
                        }
                        Blob {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            kind: ["cookie", "flower", "clover", "circle"][dot.index % 4]
                            color: pass.wrong ? "#ff8a80" : lc.acc
                            scale: dot.p + (pass.checking ? 0.25 * Math.max(0, dot.bob) : 0)
                            rotation: -160 * (1 - dot.p) + (pass.checking ? 90 * pass.ripple : 0)
                            transform: Translate { y: (1 - dot.p) * -14 - (pass.checking ? 4 * Math.max(0, dot.bob) : 0) }
                        }
                    }
                }
            }
            Text {
                anchors.left: lk.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                visible: !!lc.root && lc.root.pass === "" && !pass.touch
                text: pass.wrong && lc.root && lc.root.msg !== "" ? lc.root.msg : (pass.checking ? Tr.t("Checking ...") : (lv && lv.isPreview ? Tr.t("Password (preview, Esc closes)") : Tr.t("Enter your password")))
                color: pass.wrong ? "#ffb4ab" : lc.dim; font.family: Fonts.main; font.pixelSize: 14
                width: pass.width - 110; elide: Text.ElideRight
            }
            Text {
                anchors.left: lk.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                visible: pass.touch
                text: Tr.t("Touch your security key"); color: lc.acc; font.family: Fonts.main; font.pixelSize: 14; font.weight: Font.Medium
                width: pass.width - 70; elide: Text.ElideRight
                SequentialAnimation on opacity { running: pass.touch; loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine } }
            }
            Item {
                anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38
                visible: !!lc.root && lc.root.pass !== "" && !pass.checking
                Rectangle { anchors.fill: parent; radius: 19; color: lc.acc; scale: gm.pressed ? 0.9 : 1; Behavior on scale { NumberAnimation { duration: 120 } } }
                MIcon { anchors.centerIn: parent; size: 20; name: "arrow_forward"; glyph: ""; color: lc.ink }
                MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (lc.root) lc.root.submit() }
            }
        }

        // power
        Rectangle {
            visible: lv && lv.v("power", true) !== false
            height: 52; radius: 26; width: pr.implicitWidth + 16
            color: lc.pal ? lc.pal.surface : "#222"
            Row {
                id: pr
                anchors.centerIn: parent; spacing: 6
                property string armed: ""
                Timer { id: disarm; interval: 3000; onTriggered: pr.armed = "" }
                function act(k, cmd) {
                    if (k !== "suspend" && armed !== k) { armed = k; disarm.restart(); return }
                    armed = ""
                    if (lv && !lv.isPreview) Quickshell.execDetached(["bash", "-c", cmd])
                }
                PBtn { k: "suspend"; icon: "bedtime"; onHit: pr.act(k, "\"$HOME/.local/bin/rice-sys\" suspend") }
                PBtn { k: "reboot"; icon: "restart_alt"; onHit: pr.act(k, "\"$HOME/.local/bin/rice-sys\" reboot") }
                PBtn { k: "poweroff"; icon: "power_settings_new"; red: true; onHit: pr.act(k, "\"$HOME/.local/bin/rice-sys\" poweroff") }
            }
        }
    }

    // ---------- the month as cells (0 = an empty one) ----------
    readonly property var cells: {
        const y = now.getFullYear(), m = now.getMonth()
        const first = (new Date(y, m, 1).getDay() + 6) % 7          // Monday first
        const n = new Date(y, m + 1, 0).getDate()
        const o = []
        for (let i = 0; i < first; i++) o.push(0)
        for (let d = 1; d <= n; d++) o.push(d)
        return o
    }
    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    // ---------- parts ----------
    // a tall card that rises into place (each a moment after the one before) and lifts off on the way out
    component Card: Rectangle {
        id: cd
        property int idx: 0
        readonly property real e: lc.stg(idx + 1)
        width: lc.cw; height: lc.ch
        radius: Math.round(30 * lc.k)
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(lc.acc.r * 0.45, lc.acc.g * 0.45, lc.acc.b * 0.45, 0.82) }
            GradientStop { position: 1; color: Qt.rgba(0.06, 0.06, 0.07, 0.78) }
        }
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
        opacity: e
        transform: [
            Translate { y: (1 - cd.e) * 120 - lc.gone * (60 + cd.idx * 30) },
            Rotation { origin.x: cd.width / 2; origin.y: cd.height; angle: (1 - cd.e) * (cd.idx - 1) * 8 }
        ]
    }
    component Pill2: Item {
        id: p2
        property real w: 54
        property string icon: ""
        property bool strong: false
        signal hit()
        width: Math.round(w * Math.min(1, lc.k)); height: Math.round(46 * Math.min(1, lc.k))
        Rectangle { anchors.fill: parent; radius: pm.pressed ? 14 : height / 2; color: p2.strong ? lc.acc : Qt.rgba(lc.acc.r, lc.acc.g, lc.acc.b, 0.28)
            Behavior on radius { NumberAnimation { duration: 160 } } }
        MIcon { anchors.centerIn: parent; size: 22; name: p2.icon; glyph: ""; color: p2.strong ? lc.ink : lc.fg }
        MouseArea { id: pm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: p2.hit() }
    }
    component PBtn: Item {
        id: pb
        property string k: ""
        property string icon: ""
        property bool red: false
        signal hit()
        readonly property bool armed: parent && parent.armed === k
        width: armed ? 78 : 38; height: 38
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
        Rectangle { anchors.fill: parent; radius: 19
            color: pb.red ? Qt.rgba(1, 0.42, 0.42, pb.armed ? 0.9 : (pbm.containsMouse ? 0.32 : 0.16)) : (pb.armed ? lc.acc : (pbm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)))
            Behavior on color { ColorAnimation { duration: 150 } } }
        Row { anchors.centerIn: parent; spacing: 4
            MIcon { anchors.verticalCenter: parent.verticalCenter; size: 18; name: pb.icon; glyph: ""; color: pb.red ? (pb.armed ? "#3b0a0a" : "#ffb4ab") : (pb.armed ? lc.ink : lc.fg) }
            Text { visible: pb.armed; anchors.verticalCenter: parent.verticalCenter; text: "?"; color: pb.red ? "#3b0a0a" : lc.ink; font.family: Fonts.main; font.pixelSize: 14; font.weight: Font.Bold } }
        MouseArea { id: pbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.hit() }
    }
}
