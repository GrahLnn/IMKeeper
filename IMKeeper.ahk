#Requires AutoHotkey v2.0
Persistent
SetTitleMatchMode("RegEx")

; 注册 shell hook 消息
MsgNum := DllCall("RegisterWindowMessage", "str", "SHELLHOOK", "uint")
DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)
OnMessage(MsgNum, ShellEvent)

global mgr := InputModeManager(A_ScriptDir "\config.ini")

class WinUtil {
    static GetActiveHwnd() {
        try {
            hwnd := WinGetID("A")
            return hwnd && WinExist("ahk_id " hwnd) ? hwnd : 0
        } catch {
            return 0
        }
    }

    static GetThreadId(hwnd := 0) {
        try {
            hwnd := hwnd ? hwnd : WinUtil.GetActiveHwnd()
            if !hwnd
                return 0
            return DllCall("GetWindowThreadProcessId", "UInt", hwnd, "UInt*", 0)
        } catch {
            return 0
        }
    }

    static GetIMEWindow(hwnd := 0) {
        try {
            hwnd := hwnd ? hwnd : WinUtil.GetActiveHwnd()
            if !hwnd
                return 0
            return DllCall("imm32.dll\ImmGetDefaultIMEWnd", "UInt", hwnd)
        } catch {
            return 0
        }
    }

    static IsValid(hwnd) {
        return hwnd && WinExist("ahk_id " hwnd)
    }
}

class IME {
    static get() {
        tid := WinUtil.GetThreadId()
        return tid ? DllCall("GetKeyboardLayout", "UInt", tid) : 0
    }

    static keyboardLayoutID := Map(
        "en", 67699721,
        "ch", 134481924,
    )

    static set(lan := "en", not_to_en := False, win := "A") {
        if NOT (win_id := WinExist(win))
            return
        hWnd := DllCall("imm32.dll\ImmGetDefaultIMEWnd", "UInt", win_id)
        PostMessage(0x50, , IME.keyboardLayoutID[lan], hWnd)
        if lan == "en"
            return
        Sleep(50)
        SendMessage(0x283, 0x2, not_to_en, hWnd)
    }

    static isEnglishMode() {
        try {
            imeHwnd := WinUtil.GetIMEWindow()
            if !imeHwnd
                return -1
            DetectHiddenWindows True
            is_en := !SendMessage(0x283, 0x001, 0, , "ahk_id " imeHwnd)
            DetectHiddenWindows False
            layout := IME.get()
            return layout == IME.keyboardLayoutID["en"] ? -1 : is_en
        } catch {
            return -1
        }
    }

    static toChinese() {
        loop 50 {
            IME.set("ch", true)
            Sleep(50)
            if !IME.isEnglishMode() {
                Sleep(100)
                if !IME.isEnglishMode()
                    return true
            }
        }
        return false
    }

    static toEnglish() {
        loop 50 {
            IME.set("ch", false)
            Sleep(50)
            if IME.isEnglishMode() {
                Sleep(100)
                if IME.isEnglishMode()
                    return true
            }
        }
        return false
    }
}

class InputModeManager {
    configPath := ""
    defaultMode := Map()
    memory := Map()
    lastApp := ""
    lastFocusHwnd := 0
    suppressNextTimerEvent := false
    watcher := unset
    lastSwitchTime := 0

    __New(configPath) {
        this.configPath := configPath
        this.LoadConfig()
    }

    StartWatcher(interval := 300) {
        this.watcher := this.WatchActiveWindow.Bind(this)
        SetTimer(this.watcher, interval)
    }

    StopWatcher() {
        watcher := unset
        try watcher := this.watcher
        if IsSet(watcher)
            SetTimer(watcher, 0)
    }

    WatchActiveWindow() {

        if this.suppressNextTimerEvent {
            this.suppressNextTimerEvent := false
            return
        }
        hwnd := WinUtil.GetActiveHwnd()
        if hwnd && hwnd != this.lastFocusHwnd {
            this.DoWindowSwitch(hwnd, "timer")
        }
    }

    OnShellEvent(event, hwnd) {
        if event != 4
            return
        if !WinUtil.IsValid(hwnd) || hwnd == this.lastFocusHwnd
            return
        this.DoWindowSwitch(hwnd, "shell")
        this.suppressNextTimerEvent := true
    }

    DoWindowSwitch(newHwnd, source := "unknown") {
        now := A_TickCount
        if (now - this.lastSwitchTime < 200) {
            ; TrayTip("skip duplicate trigger from " source)
            return
        }
        this.lastSwitchTime := now

        ; TrayTip("switch by " source)
        if this.lastFocusHwnd
            this.OnWindowBlur(this.lastFocusHwnd)
        this.OnWindowFocus(newHwnd)
        this.lastFocusHwnd := newHwnd
    }

    OnWindowBlur(hwnd) {
        if !WinUtil.IsValid(hwnd)
            return
        try {
            ; TrayTip("blur " . WinGetProcessName(hwnd) . " " . IME.isEnglishMode())
        }
    }

    OnWindowFocus(hwnd) {
        if !WinUtil.IsValid(hwnd)
            return
        try {
            curApp := WinGetProcessName(hwnd)
            if this.memory.Has(curApp) {
                if this.memory[curApp]
                    IME.toEnglish()
                else
                    IME.toChinese()
            } else if this.defaultMode.Has(curApp) {
                mode := this.defaultMode[curApp]
                if (mode = "ENG")
                    IME.toEnglish()
                else if (mode = "CHN")
                    IME.toChinese()
            }

            this.lastApp := curApp
        }
    }

    LoadConfig() {
        this.defaultMode.Clear()
        if !FileExist(this.configPath)
            IniWrite("WindowsTerminal.exe=ENG", this.configPath, "DefaultInputMethod")
        section := IniRead(this.configPath, "DefaultInputMethod", , "")
        for _, line in StrSplit(section, "`n", "`r") {
            line := Trim(line)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            parts := StrSplit(line, "=")
            if parts.Length = 2 {
                app := Trim(parts[1])
                lang := Trim(parts[2])
                this.defaultMode[app] := lang
            }
        }
    }

    Cleanup(*) {
        this.StopWatcher()
        this.memory.Clear()
    }
}

ShellEvent(wParam, lParam, msg, hwnd) {
    mgr.OnShellEvent(wParam, lParam)
}

mgr.StartWatcher()
OnExit(mgr.Cleanup.Bind(mgr))