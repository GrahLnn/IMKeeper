@echo off
chcp 65001 > nul
setlocal

set "EXE_NAME=IMKeeper.exe"
set "EXE_PATH=%~dp0%EXE_NAME%"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\IMKeeper.lnk"

powershell -NoProfile -Command ^
 "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');" ^
 "$s.TargetPath='%EXE_PATH%';" ^
 "$s.WorkingDirectory='%~dp0';" ^
 "$s.WindowStyle=1;" ^
 "$s.Description='IMKeeper 启动项';" ^
 "$s.Save()"

if exist "%SHORTCUT_PATH%" (
    echo ✅ 启动项创建成功！
    timeout /t 1 > nul
) else (
    echo ❌ 创建失败，请确认路径是否正确。
    pause
)