import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

// The lock screen of DarkShadow's Shell (Settings > Idle & Lockscreen), started by `rice-lock now`.
// It locks the session with the Wayland session-lock protocol (so nothing can be seen or clicked behind it) and
// checks your password with PAM (the same rules hyprlock uses). rice-lock watches it: if it does not lock within a
// few seconds, or quits without unlocking, hyprlock takes over, so you can never be locked out.
// RICE_LOCK_PREVIEW=1 shows it in a normal full-screen window (Settings > Preview): Esc closes it.
// The shared parts (Look, Fonts, Blob, WavyLine ...) are copied here from rice-desktop by rice-lock.
ShellRoot {
    id: lockShell
    // the views reach this through LockCtx (an id or a property passed into the lock window was not always seen)
    Component.onCompleted: LockCtx.root = lockShell
    readonly property bool preview: Quickshell.env("RICE_LOCK_PREVIEW") === "1"
    readonly property string home: Quickshell.env("HOME")

    // ---------- settings (rice-lock state) ----------
    property var cfg: ({})
    property bool ready: false
    function v(k, d) { return cfg[k] !== undefined ? cfg[k] : d }
    Process {
        running: true
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-lock\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            try { lockShell.cfg = JSON.parse(text) } catch (e) { lockShell.cfg = {} }
            if (/^#[0-9a-fA-F]{6}$/.test(lockShell.cfg.accent || "")) Look.accent = lockShell.cfg.accent
            lockShell.ready = true
        } }
    }
    // your shape and wavy progress (Settings > Appearance)
    Process {
        running: true
        command: ["bash", "-c", "cat \"$HOME/.config/rice/settings-app.json\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            let j = {}
            try { j = text.trim() !== "" ? JSON.parse(text) : {} } catch (e) { j = {} }
            Look.wavy = j.wavy !== false
            if (typeof j.accentShape === "string" && j.accentShape !== "") Look.shape = j.accentShape
            Look.waveThick = j.progressThick !== undefined ? Math.max(2, Math.min(8, Number(j.progressThick))) : 4
        } }
    }

    // ---------- the password (shared by every screen) ----------
    property string pass: ""
    property string pending: ""
    property string phase: "idle"            // idle | checking | wrong | done
    property string msg: ""
    // a security key (pam_u2f) asked to be touched and is waiting for it
    property bool touch: false
    property int tries: 0
    // rice-lock test: a real lock that unlocks itself after 30 seconds (to try the keyboard without risk)
    readonly property bool testMode: Quickshell.env("RICE_LOCK_TEST") === "1"
    property int testLeft: 30
    Timer {
        running: lockShell.testMode && lock.secure && lockShell.phase !== "done"
        interval: 1000; repeat: true
        onTriggered: { lockShell.testLeft--; if (lockShell.testLeft <= 0) { console.log("[lock] test over: unlocking"); lockShell.phase = "done"; lockShell.unlock() } }
    }
    // the keyboard never came: quit WITHOUT unlocking (the session stays locked) and rice-lock starts hyprlock
    function fallback() {
        console.warn("[lock] switching to hyprlock (the keyboard did not reach the lock screen)")
        fbP.running = true
    }
    Process {
        id: fbP
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/rice\"; touch \"$HOME/.cache/rice/lock-fallback\""]
        onExited: Qt.exit(3)
    }
    property int secureTick: 0
    function submit() {
        if (phase === "checking" || phase === "done" || pass === "" || waitT.running) return
        pending = pass
        phase = "checking"; msg = ""; touch = false
        if (pam.active && pam.responseRequired) { pam.respond(pending); pending = ""; return }
        if (pam.active) return                 // it asks for the password in a moment (onResponseRequiredChanged)
        console.log("[lock] checking the password with PAM:", pam.config)
        if (!pam.start()) {
            console.warn("[lock] PAM did not start (" + pam.config + ")")
            fail(Tr.t("Could not check the password (PAM did not start)"))
        }
    }
    function fail(text) {
        tries++
        // 1, 2, 4 ... 30 s between tries: a keyboard cannot guess passwords quickly through PAM
        wait = Math.min(30, Math.pow(2, Math.min(tries - 1, 5)))
        waitT.restart()
        phase = "wrong"
        msg = text
        pass = ""; pending = ""
        wrongT.restart()
    }
    PamContext {
        id: pam
        // hyprlock's PAM file when it is there (it is set up for exactly this), else the login rules
        config: lockShell.cfg.pam || "login"
        onResponseRequiredChanged: if (responseRequired && lockShell.pending !== "") { respond(lockShell.pending); lockShell.pending = "" }
        onPamMessage: {
            console.log("[lock] PAM says:", message, messageIsError ? "(error)" : "")
            if (messageIsError) lockShell.msg = message
            // pam_u2f's cue ("Please touch the device."): the key is blinking now
            // checkT starts over: the touch gets its own 20 s, not what the password check left of them
            else if (/touch|tap|presence|security key|device/i.test(message)) { lockShell.touch = true; checkT.restart() }
        }
        onError: function(e) { console.warn("[lock] PAM error", e); lockShell.msg = Tr.t("Could not check the password") }
        onCompleted: function(result) {
            console.log("[lock] PAM finished:", result === PamResult.Success ? "right password" : "result " + result)
            if (lockShell.phase !== "checking") return      // the attempt was given up (checkT): its result is old
            const touched = lockShell.touch
            lockShell.touch = false
            if (result === PamResult.Success) { lockShell.phase = "done"; lockShell.pending = ""; lockShell.unlock(); return }
            // a stack that checks the password first (on NixOS: unix requisite, then u2f) only asks for the
            // touch after a right password, so a failure after the cue means the key was not touched
            lockShell.fail(lockShell.msg !== "" ? lockShell.msg : (result === PamResult.MaxTries ? Tr.t("Too many tries, wait a moment")
                : (touched ? Tr.t("The security key was not touched, try again") : Tr.t("That is not the password"))))
        }
    }
    property int wait: 0                     // seconds left before the next try
    Timer { id: waitT; interval: 1000; repeat: true
            onTriggered: { lockShell.wait--; if (lockShell.wait <= 0) stop() } }
    // a PAM stack that never asks and never finishes (a hung module, a second factor this screen cannot answer)
    // would leave the field read-only forever: give up after 20 s and take the keyboard back
    Timer { id: checkT; interval: 20000; running: lockShell.phase === "checking"
            onTriggered: {
                console.warn("[lock] PAM did not answer; the attempt was dropped")
                if (pam.active) pam.abort()
                const touched = lockShell.touch
                lockShell.phase = "idle"; lockShell.pending = ""; lockShell.pass = ""; lockShell.touch = false
                lockShell.msg = touched ? Tr.t("The security key was not touched, try again") : Tr.t("Could not check the password (PAM did not answer)")
            } }
    Timer { id: wrongT; interval: 2600; onTriggered: if (lockShell.phase === "wrong") { lockShell.phase = "idle"; lockShell.msg = lockShell.wait > 0 ? Tr.t("Wait") + " " + lockShell.wait + " s" : "" } }

    // ---------- locking and unlocking ----------
    property real out: 0                     // 0 shown .. 1 gone (the way out after the right password)
    NumberAnimation { id: outA; target: lockShell; property: "out"; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Look.accel
        onFinished: { lock.locked = false; quitT.restart() } }
    Timer { id: quitT; interval: 150; onTriggered: { Quickshell.execDetached(["rm", "-f", lockShell.home + "/.cache/rice/lock-active"]); Qt.quit() } }
    function unlock() { outA.restart() }
    // tells rice-lock that the screen is really locked (the compositor confirmed it)
    function tellLocked() { Quickshell.execDetached(["bash", "-c", "mkdir -p \"$HOME/.cache/rice\"; echo $PPID > \"$HOME/.cache/rice/lock-active\""]) }

    WlSessionLock {
        id: lock
        locked: !lockShell.preview
        onSecureChanged: { console.log("[lock] the compositor locked the session:", secure); if (secure) { lockShell.tellLocked(); lockShell.secureTick++ } }
        WlSessionLockSurface {
            color: "black"
            LockView { anchors.fill: parent; focus: true; scr: screen }
        }
    }

    // ---------- preview: the same thing in a window you can close ----------
    Variants {
        model: lockShell.preview ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "black"
            LockView { anchors.fill: parent; focus: true; scr: modelData; isPreview: true }
        }
    }
}
