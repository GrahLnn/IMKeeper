#Requires AutoHotkey v2.0
Persistent
SetTitleMatchMode("RegEx")

; 注册 shell hook 消息
MsgNum := DllCall("RegisterWindowMessage", "str", "SHELLHOOK", "uint")
DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)
OnMessage(MsgNum, ShellEvent)

global mgr := InputModeManager(A_ScriptDir "\config.ini")

class IME {
    static get := (*) => DllCall("GetKeyboardLayout", "UInt",
        DllCall("GetWindowThreadProcessId", "UInt", WinGetID("A"), "UInt", 0))

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
        DetectHiddenWindows True
        is_en := NOT SendMessage(0x283, 0x001, 0, , "ahk_id " . DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", WinGetID(
            "A")))
        DetectHiddenWindows False
        return IME.get() == IME.keyboardLayoutID["en"] ? -1 : is_en
    }

    static toChinese() {
        loop 5 {
            IME.set("ch", true)
            Sleep(50)
            if !IME.isEnglishMode()
                return true
        }
        return false
    }

    static toEnglish() {
        loop 5 {
            IME.set("ch", false)
            Sleep(50)
            if IME.isEnglishMode()
                return true
        }
        return false
    }
}

class InputModeManager {
    configPath := ""
    defaultMode := Map()
    memory := Map()
    lastApp := ""
    lastConfigTime := 0
    lastFocusHwnd := 0

    __New(configPath) {
        this.configPath := configPath
        this.LoadConfig()
        this.lastConfigTime := FileGetTime(configPath, "M")
    }

    OnWindowBlur(hwnd) {
        try {
            ; app := WinGetProcessName(hwnd)
            ; TrayTip("blur " . app . " " . IME.isEnglishMode())
            ; if app != ""
            ;     this.memory[app] := IME.isEnglishMode()
        }
    }

    OnWindowFocus(hwnd) {
        try {
            curApp := WinGetProcessName(hwnd)

            if (this.memory.Has(curApp)) {
                if this.memory[curApp] {
                    IME.toEnglish()
                }
                else
                    IME.toChinese()
            } else if (this.defaultMode.Has(curApp)) {
                target := this.defaultMode[curApp]
                if (target = "ENG") {
                    IME.toEnglish()
                }
                else if (target = "CHN")
                    IME.toChinese()
            }
            this.lastApp := curApp

        } catch {
        }
    }

    OnShellEvent(event, hwnd) {
        if (event = 4) { ; HSHELL_WINDOWACTIVATED
            if (this.lastFocusHwnd)
                this.OnWindowBlur(this.lastFocusHwnd)
            this.OnWindowFocus(hwnd)
            this.lastFocusHwnd := hwnd
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
        this.memory.Clear()
    }
}

ShellEvent(wParam, lParam, msg, hwnd) {
    mgr.OnShellEvent(wParam, lParam)
}

OnExit(mgr.Cleanup.Bind(mgr))