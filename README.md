# Input Method Keeper

避免微软拼音输入法在不同窗口切换时胡乱切换中/英状态，并能自由设置初始状态

## Feature

- [x] 设定应用程序的默认输入法状态
- [ ] 当窗口重新获得焦点时，根据记忆回到正确的输入法状态

## Usage

1. `git clone https://github.com/GrahLnn/IMKeeper.git`
2. 配置`config.ini`（需要正确配置应用程序名，可以通过`curApp := WinGetProcessName(hwnd)`自行检查）
3. 双击运行`IMKeeper.exe`（修改`config.ini`后需要重新启动）
4. 双击`.bat`添加到开机启动项（可选）
5. 其他需要自行修改`.ahk`代码并编译