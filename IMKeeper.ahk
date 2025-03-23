#Requires AutoHotkey v2.0
Persistent
SetTitleMatchMode("RegEx")

class IME {
    static get := (*) => DllCall("GetKeyboardLayout", "UInt",
        DllCall("GetWindowThreadProcessId", "UInt", WinGetID("A"), "UInt", 0))

    static keyboardLayoutID := Map(
        "en", 67699721,
        "ch", 134481924,
        ; more language
    )

    static set(lan := "en", not_to_en := False, win := "A") {
        if NOT (win_id := WinExist(win))
            return
        hWnd := DllCall("imm32.dll\ImmGetDefaultIMEWnd", "UInt", win_id)
        PostMessage(0x50, , IME.keyboardLayoutID[lan], hWnd)
        ; 0x50: WM_INPUTLANGCHANGEREQUEST
        if lan == "en"
            return
        Sleep(50), SendMessage(0x283, 0x2, not_to_en, hWnd)
        ; 0x283: WM_IME_CONTROL, 0x2: IMC_SETOPENSTATUS，lParam: 0-en | 1-!en
    }

    static isEnglishMode() {
        DetectHiddenWindows True
        is_en := NOT SendMessage(
            0x283, ; Message: WM_IME_CONTROL
            0x001, ; wParam: IMC_GETCONVERSIONMODE
            0, ; lParam: (NoArgs)
            , ; Control: (Window), Retrieves the default window handle.
            "ahk_id " . DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", WinGetID("A")))
        DetectHiddenWindows False
        return IME.get() == IME.keyboardLayoutID["en"] ? -1 : is_en
    }
    static toChinese() => IME.set("ch", true)
    static toEnglish() => IME.set("ch", false)
}

class InputModeManager {
    configPath := ""
    defaultMode := Map()
    lastApp := ""
    lastConfigTime := 0

    __New(configPath) {
        this.configPath := configPath
        this.LoadConfig()
        this.lastConfigTime := FileGetTime(configPath, "M")
    }

    OnShellHook(*) {
        try {
            hwnd := WinActive("A")
            curApp := WinGetProcessName(hwnd)

            if (curApp != this.lastApp) {
                this.lastApp := curApp
                if (this.defaultMode.Has(curApp)) {
                    target := this.defaultMode[curApp]
                    isEng := IME.isEnglishMode()
                    if (target = "ENG" && !isEng)
                        IME.toEnglish()
                    else if (target = "CHN" && isEng)
                        IME.toChinese()
                }
            }
        } catch {
            ; 忽略无权限窗口
        }
    }

    MonitorConfig(*) {
        time := FileGetTime(this.configPath, "M")
        if (time != this.lastConfigTime) {
            this.LoadConfig()
            this.lastConfigTime := time
        }
    }

    LoadConfig() {
        this.defaultMode.Clear()

        if !FileExist(this.configPath) {
            IniWrite("WindowsTerminal.exe=ENG", this.configPath, "DefaultInputMethod")
        }

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
        ; 清理任务
    }
}

; ===== 主程序入口 =====
mgr := InputModeManager(A_ScriptDir "\config.ini")
MsgNum := DllCall("RegisterWindowMessage", "str", "SHELLHOOK", "uint")
DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)
OnMessage(MsgNum, mgr.OnShellHook.Bind(mgr))
; SetTimer(mgr.MonitorConfig.Bind(mgr), 1000)
OnExit(mgr.Cleanup.Bind(mgr))