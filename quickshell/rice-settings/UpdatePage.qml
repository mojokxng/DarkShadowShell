import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Update Center: your version, the newest one on GitHub and what is new in it, and the update itself,
// right here: no terminal. rice-update gui runs the installer in the background (it keeps going when Settings
// reloads with its new files) and this page reads what it does, live, from ~/.cache/rice/update-live.log.
Item {
    id: page
    property var ctl

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/rice-update"
    property var st: ({})            // rice-update check: installed, latest, update, news, error
    property var lv: ({})            // the update that runs (or ran): state, started, ended, was, now
    property var steps: []           // what the installer did: { k: run|ok|fail|warn|info|title|note, t }
    property bool checking: false
    property bool starting: false
    property int now: Math.floor(Date.now() / 1000)

    readonly property bool running: lv.state === "running" || starting
    readonly property bool finished: !running && (lv.state === "done" || lv.state === "failed")
    readonly property bool failed: !running && lv.state === "failed"
    readonly property bool hasUpdate: !!st.update
    readonly property int doneCount: steps.filter(function(s) { return s.k === "ok" || s.k === "fail" }).length
    readonly property var current: {
        for (let i = steps.length - 1; i >= 0; i--) if (steps[i].k === "run") return steps[i]
        return null
    }
    // about 40 steps make an update; the bar never says it is done before it is
    readonly property real progress: finished ? 1 : Math.min(0.95, doneCount / 42)

    function fmtTime(s) {
        s = Math.max(0, s)
        const m = Math.floor(s / 60)
        return m > 0 ? I18n.t("%1 min %2 s", m, s % 60) : I18n.t("%1 s", s)
    }
    function ago(t) {
        if (!t) return ""
        const d = page.now - t
        if (d < 60) return I18n.t("just now")
        if (d < 3600) return I18n.t("%1 min ago", Math.floor(d / 60))
        if (d < 86400) return I18n.t("%1 h ago", Math.floor(d / 3600))
        return I18n.t("%1 days ago", Math.floor(d / 86400))
    }

    // the installer's output, line by line, as steps: "▶ x" starts x, "✔ x" / "✘ x" ends it
    function parse(text) {
        const out = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i].replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\s+$/, "")
            const l = raw.trim()
            if (!l || /^[╭╰│─]/.test(l)) continue
            const ind = raw.length - raw.replace(/^\s+/, "").length
            const head = l.charAt(0), rest = l.substring(1).trim().replace(/\s+\(details: .*\)$/, "")
            if (head === "▶") { out.push({ k: "run", t: rest.replace(/ +-> +/g, "  →  ") }); continue }
            if (head === "✔" || head === "✘") {
                let hit = false
                for (let j = out.length - 1; j >= 0 && j >= out.length - 4; j--)
                    if (out[j].k === "run" && out[j].t === rest.replace(/ +-> +/g, "  →  ")) { out[j] = { k: head === "✔" ? "ok" : "fail", t: out[j].t }; hit = true; break }
                if (!hit) out.push({ k: head === "✔" ? "ok" : "fail", t: rest.replace(/ +-> +/g, "  →  ") })
                continue
            }
            if (head === "!") { out.push({ k: "warn", t: rest }); continue }
            if (head === "•") { out.push({ k: "info", t: rest }); continue }
            if (ind <= 2) { out.push({ k: "title", t: l.replace(/^\[\d+\/\d+\]\s*/, "") }); continue }
            if (ind >= 6) { out.push({ k: "note", t: l }); continue }
            // "Key       value" lines (Your system) stay out: they are in About
        }
        // a step that was running when the update stopped did not finish
        if (lv.state === "failed") for (let k = 0; k < out.length; k++) if (out[k].k === "run") out[k] = { k: "fail", t: out[k].t }
        return out
    }

    Process {
        id: stateP
        command: ["bash", "-c", "cat \"$HOME/.cache/rice/update.json\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.st = JSON.parse(text) } catch (e) { page.st = {} }
                // nothing checked yet, or long ago: ask GitHub now
                if (!page.st.checked || page.now - page.st.checked > 600) page.check()
            }
        }
    }
    Process {
        id: checkP
        command: [page.bin, "check", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.checking = false
                try { page.st = JSON.parse(text.trim().split("\n").pop()) } catch (e) {}
                page.ctl.status = page.st.update ? I18n.t("Update V%1 is available", page.st.latest) : I18n.t("Up to date")
            }
        }
        onExited: page.checking = false
    }
    function check() { if (checkP.running || page.running) return; page.checking = true; checkP.running = true }

    Process {
        id: liveP
        command: ["bash", "-c", "cat \"$HOME/.cache/rice/update-live.json\" 2>/dev/null; printf '\\n\\x1e\\n'; tail -n 400 \"$HOME/.cache/rice/update-live.log\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const cut = text.indexOf("\x1e")
                let o = {}
                try { o = JSON.parse(text.substring(0, cut).trim() || "{}") } catch (e) {}
                const was = page.lv.state
                page.lv = o
                if (page.starting && (o.state === "running" || (o.started && o.started >= page.startedAt))) page.starting = false
                page.steps = page.parse(cut >= 0 ? text.substring(cut + 1) : "")
                if (was === "running" && o.state !== "running") { stateP.running = true; page.ctl.status = o.state === "done" ? I18n.t("Updated") : I18n.t("The update did not finish") }
            }
        }
    }
    property int startedAt: 0
    Timer {
        interval: page.running ? 450 : 4000
        repeat: true
        running: page.visible
        onTriggered: { page.now = Math.floor(Date.now() / 1000); if (!liveP.running) liveP.running = true }
    }
    // the button press: the update starts, and after a reload Settings comes back to this page by itself
    function update(withPackages) {
        if (page.running) return
        if (withPackages) {
            Quickshell.execDetached(["bash", "-c", "t=\"$HOME/.local/bin/rice-term\"; [ -x \"$t\" ] || t=\"${TERMINAL:-kitty}\"; exec \"$t\" -e \"$HOME/.local/bin/rice-update\""])
            return
        }
        page.startedAt = Math.floor(Date.now() / 1000)
        page.starting = true
        page.steps = []
        Quickshell.execDetached([page.bin, "gui"])
        startGuard.restart()
    }
    Timer { id: startGuard; interval: 15000; onTriggered: page.starting = false }

    PageScroll {
        id: scroll
        anchors.fill: parent

        // ---------- the state, at the top ----------
        Rectangle {
            width: parent.width
            height: heroCol.implicitHeight + 44
            radius: M3.rXL
            color: page.failed ? M3.alpha(M3.error, 0.16) : M3.primaryContainer
            clip: true
            Behavior on color { ColorAnimation { duration: 300 } }
            Rectangle { width: 240; height: 240; radius: 120; x: parent.width - 260; y: -110; color: M3.alpha(M3.primary, 0.14) }
            Rectangle { width: 120; height: 120; radius: 40; rotation: 22; x: parent.width - 150; y: parent.height - 70; color: M3.alpha(M3.primary, 0.10) }

            // the big round icon: turns while it updates
            Rectangle {
                id: badge
                x: 24; y: 22
                width: 76; height: 76; radius: 38
                color: M3.primary
                Icon {
                    anchors.centerIn: parent
                    size: 34
                    name: page.running ? "sync" : (page.failed ? "error" : (page.finished && !page.hasUpdate ? "check_circle" : (page.hasUpdate ? "system_update_alt" : "verified")))
                    glyph: page.running ? "" : (page.failed ? "" : (page.hasUpdate ? "" : ""))
                    color: M3.inkPrimary
                    RotationAnimation on rotation { running: page.running; from: 0; to: -360; duration: 1400; loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.rotation = 0 }
                }
                // a ring that fills while it updates
                Canvas {
                    id: ring
                    anchors.fill: parent; anchors.margins: -7
                    visible: page.running || page.finished
                    property real p: page.progress
                    Behavior on p { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    onPChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"), r = width / 2 - 2
                        c.reset(); c.lineWidth = 3.5; c.lineCap = "round"
                        c.strokeStyle = M3.alpha(M3.primary, 0.22); c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke()
                        c.strokeStyle = M3.primary; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p); c.stroke()
                    }
                }
            }
            Column {
                id: heroCol
                x: 124; y: 22
                width: parent.width - 124 - 24
                spacing: 6
                T { kind: "title"; font.pixelSize: 26; font.weight: Font.Medium; color: M3.inkPrimaryC; width: parent.width; wrapMode: Text.WordWrap
                    text: page.running ? I18n.t("Updating...")
                        : page.failed ? I18n.t("The update did not finish")
                        : page.finished && !page.hasUpdate && page.lv.ended && page.now - page.lv.ended < 3600 ? I18n.t("Updated to V%1", page.st.installed || page.lv.now || "?")
                        : page.hasUpdate ? I18n.t("V%1 is available", page.st.latest)
                        : page.checking ? I18n.t("Looking for updates...")
                        : I18n.t("You are up to date") }
                T { kind: "reading"; font.pixelSize: 13; color: M3.inkPrimaryC; opacity: 0.85; width: parent.width; wrapMode: Text.WordWrap
                    text: page.running ? (page.current ? page.current.t : I18n.t("Getting the newest version from GitHub..."))
                        : page.failed ? I18n.t("Nothing is broken: what was done stays, the rest keeps your old files. Try again, or look at the steps below.")
                        : page.hasUpdate ? (page.st.installed !== page.st.latest ? I18n.t("You have V%1.", page.st.installed) : I18n.t("%1 new changes on GitHub.", page.st.changes))
                        : I18n.t("DarkShadow's Shell V%1", page.st.installed || "?") + (page.st.checked ? "  ·  " + I18n.t("checked %1", page.ago(page.st.checked)) : "") }
                // the progress line while it runs
                Item {
                    width: parent.width; height: page.running ? 22 : 0
                    visible: page.running
                    Rectangle {
                        y: 8; width: parent.width; height: 6; radius: 3; color: M3.alpha(M3.primary, 0.2)
                        Rectangle { width: Math.max(12, parent.width * page.progress); height: parent.height; radius: 3; color: M3.primary
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
                    }
                    T { anchors.right: parent.right; y: -10; font.pixelSize: 11; color: M3.inkPrimaryC; opacity: 0.7
                        text: page.lv.started ? page.fmtTime(page.now - page.lv.started) : "" }
                }
                Row {
                    spacing: 8
                    topPadding: 6
                    Btn { visible: !page.running && (page.hasUpdate || page.failed); primary: true; sym: "download"; icon: ""
                        text: page.failed ? I18n.t("Try again") : I18n.t("Update now"); onClicked: page.update(false) }
                    Btn { visible: !page.running; sym: "refresh"; icon: ""; primary: !page.hasUpdate && !page.failed
                        text: page.checking ? I18n.t("Checking...") : I18n.t("Check for updates"); onClicked: page.check() }
                    Btn { visible: page.running; sym: "hourglass_top"; icon: ""; variant: "text"; text: I18n.t("You can close Settings: it keeps going"); onClicked: {} }
                }
            }
        }
        T { visible: !!page.st.error && !page.running; text: I18n.t("Could not reach GitHub: %1", page.st.error || ""); font.pixelSize: 12; color: M3.inkDim
            leftPadding: 6; width: parent.width; wrapMode: Text.WordWrap }
        // a package manager owns the shell (NixOS: rice-update is a stub that says "managed" and never updates)
        T { visible: !!page.st.managed; text: page.st.managed || ""; font.pixelSize: 12; color: M3.inkDim
            leftPadding: 6; width: parent.width; wrapMode: Text.WordWrap }

        // ---------- what the update is doing, live ----------
        SectionTitle {
            visible: page.running || page.steps.length > 0
            text: page.running ? I18n.t("Now") : I18n.t("Last update")
            sub: page.running ? I18n.t("Every step, as it happens.")
                : (page.lv.ended ? I18n.t("Finished %1, took %2.", page.ago(page.lv.ended), page.fmtTime(page.lv.ended - page.lv.started)) : "")
        }
        Rectangle {
            id: logBox
            visible: page.running || page.steps.length > 0
            width: parent.width
            height: Math.min(420, Math.max(80, stepList.contentHeight + 24))
            radius: M3.rL
            color: M3.surfaceC
            border.width: 1; border.color: M3.outlineVariant
            clip: true
            ListView {
                id: stepList
                anchors.fill: parent; anchors.margins: 12
                model: page.steps
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                // the newest step stays in view while it runs
                onCountChanged: if (page.running) Qt.callLater(function() { stepList.positionViewAtEnd() })
                WheelScroll { flick: stepList }
                add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 220 } NumberAnimation { properties: "x"; from: 14; to: 0; duration: 260; easing.type: Easing.OutCubic } }
                delegate: Item {
                    width: stepList.width
                    height: modelData.k === "title" ? 34 : (modelData.k === "note" ? Math.max(18, nt.implicitHeight + 2) : Math.max(28, stx.implicitHeight + 8))
                    // a section of the installer
                    T { visible: modelData.k === "title"; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; x: 4
                        text: modelData.t; font.pixelSize: 12; font.weight: Font.DemiBold; color: M3.primary; font.letterSpacing: 0.4 }
                    // a step: a spinner while it runs, then ✔ or ✘
                    Item {
                        visible: modelData.k !== "title" && modelData.k !== "note"
                        anchors.fill: parent
                        Rectangle {
                            id: dot
                            x: 2; anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 20; radius: 10
                            color: modelData.k === "ok" ? M3.alpha(M3.primary, 0.18)
                                : modelData.k === "fail" ? M3.alpha(M3.error, 0.2)
                                : modelData.k === "warn" ? M3.alpha("#E8B04A", 0.2) : "transparent"
                            // the spinner: an arc that turns
                            Canvas {
                                anchors.fill: parent
                                visible: modelData.k === "run"
                                onPaint: { const c = getContext("2d"); c.reset(); c.lineWidth = 2.4; c.lineCap = "round"; c.strokeStyle = M3.primary
                                    c.beginPath(); c.arc(10, 10, 7.5, 0, Math.PI * 1.4); c.stroke() }
                                RotationAnimation on rotation { running: modelData.k === "run" && page.visible; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                            }
                            T { visible: modelData.k !== "run"; anchors.centerIn: parent; font.pixelSize: 11; font.bold: true
                                text: modelData.k === "ok" ? "✓" : modelData.k === "fail" ? "✕" : modelData.k === "warn" ? "!" : "•"
                                color: modelData.k === "ok" ? M3.primary : modelData.k === "fail" ? M3.error : modelData.k === "warn" ? "#E8B04A" : M3.inkDim }
                        }
                        T {
                            id: stx
                            x: 32; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36
                            text: modelData.t
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                            font.weight: modelData.k === "run" ? Font.Medium : Font.Normal
                            color: modelData.k === "run" ? M3.ink : (modelData.k === "fail" ? M3.error : (modelData.k === "info" ? M3.inkDim : M3.ink))
                            opacity: modelData.k === "ok" ? 0.82 : 1
                        }
                    }
                    T { id: nt; visible: modelData.k === "note"; x: 32; width: parent.width - 36; text: modelData.t; wrapMode: Text.WordWrap
                        font.pixelSize: 11; color: M3.inkDim }
                }
            }
        }
        Row {
            visible: page.finished
            spacing: 8
            Btn { text: I18n.t("Full log"); sym: "description"; icon: ""; variant: "tonal"
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.cache/rice/update-live.log"]) }
        }

        // ---------- what is new ----------
        SectionTitle {
            visible: (page.st.news || []).length > 0
            text: page.hasUpdate ? I18n.t("What is new in V%1", page.st.latest) : I18n.t("New in V%1", page.st.installed || "")
        }
        Column {
            visible: (page.st.news || []).length > 0
            width: parent.width
            spacing: 6
            Repeater {
                model: page.st.news || []
                delegate: Rectangle {
                    width: parent.width
                    height: nw.implicitHeight + 22
                    radius: M3.rM
                    color: M3.surfaceC
                    Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: M3.primary }
                    T { id: nw; x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48; wrapMode: Text.WordWrap
                        font.pixelSize: 13; text: modelData.replace(/\*\*/g, "") }
                }
            }
            Btn { text: I18n.t("All changes on GitHub"); sym: "open_in_new"; icon: ""; variant: "text"
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/shadowww-dev/DarkShadowShell/blob/main/CHANGELOG.md"]) }
        }

        // ---------- more ----------
        SectionTitle { text: I18n.t("More"); sub: I18n.t("Updates here bring the shell, its apps and your configs. New system packages need your password, so they update in a terminal.") }
        Rectangle {
            width: parent.width
            height: 70
            radius: M3.rM
            color: M3.surfaceC
            Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 20; color: M3.secondaryContainer
                Icon { anchors.centerIn: parent; name: "terminal"; glyph: ""; size: 18; color: M3.inkSecondaryC } }
            Column {
                x: 68; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 68 - pkgBtn.width - 28
                spacing: 2
                T { text: I18n.t("Update with packages"); font.pixelSize: 14; font.weight: Font.Medium }
                T { text: I18n.t("The full update in a terminal: packages too (asks for your password)."); font.pixelSize: 11; color: M3.inkDim; width: parent.width; elide: Text.ElideRight }
            }
            Btn { id: pkgBtn; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                enabled: !page.running; text: I18n.t("Open"); sym: "open_in_new"; icon: ""; onClicked: page.update(true) }
        }
    }
}
