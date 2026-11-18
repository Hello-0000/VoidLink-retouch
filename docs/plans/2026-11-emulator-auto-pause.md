# 模拟器自动暂停/收起/继续 — 开发计划

日期：2026-11-18。目标：离开 iPad 串流时（锁屏、回主屏、退出、iPad 被挂起、断线），PC 上正在运行的模拟器自动暂停；回来时（解锁、回前台、重连）自动继续。如果离开期间有人在 PC 上本地工作过，模拟器就保持收起，不再自动呼出。

由 PC 上的 host agent 负责判断；VoidLink 只上报"离开"和"回来"；AHK 只执行窗口动作。

## 涉及的三个仓库
| 组件 | 路径 | 仓库 |
|---|---|---|
| AHK | `/Users/liuwei/Dev/Utilities/pc/ahk-scripts/mac-keyboard-ahk-v2.ahk`（PC 上路径为 `D:\Dev\Utilities\pc\ahk-scripts\`） | `/Users/liuwei/Dev/Utilities`（私有） |
| host agent | `/Users/liuwei/Dev/Utilities/pc/voidlink-host-agent/`（`voidlink_host_agent.py`、`config.json`、`README.md`） | 同上 |
| VoidLink | `/Users/liuwei/Dev/Projects/VoidLink-retouch`，分支 `my-build` | — |

PC 端代码在 Mac 上无法运行。Python 至少要通过 `python3 -m py_compile`；AHK 要仔细自查语法（v2）。

## 已确认的决定
- 暂停利用模拟器自带的"失焦即暂停"：Eden 已经开启；Ryujinx（Ryubing）请在其设置里打开 *Focus Lost Action → Pause*，这一项由用户在 PC 上自行设置。所以暂停就是把焦点从模拟器移走，继续就是重新激活模拟器，**不发送暂停键**。所有动作都必须幂等，重复执行不能把状态反转。
- 全屏 PC 游戏（非模拟器）和桌面：离开时什么都不做。
- 退出串流后重新连接：同样会自动继续。
- 不再用"大屏开着 = 工作模式"来判断，改用"离开期间 PC 上是否有本地输入"。原因：用户有时大屏没关也在玩模拟器。

## 决策表（在 agent 中实现）
**离开时**（一个会话从活跃变为离开或结束，只处理一次）：
- 取"离开前最后一次活跃采样"。如果那时被串流屏幕的最上层是模拟器进程（在 `emulators` 名单里），并且处于运行中，即 `mode == game` 且 `reason` 属于 running / known / fullscreen / rule，就执行：
  - 有其他激活的显示器（大屏开着）→ `hide`：先移走焦点，再收进 RBTray 托盘。
  - 只有被串流的那块屏 → `pause`：只移走焦点，窗口仍然显示。
- 记录本次暂停 `parked = {pid, exe, action, t_leave, last_input_tick}`。
- 模拟器处于 idle / dialog（游戏列表、弹窗）、全屏 PC 游戏、桌面：什么都不做。

**离开期间**（采样线程轮询）：
- 读 `GetLastInputInfo`。离开后 2 秒宽限期以外，如果输入时间戳比记录时前进了，就设 `local_use = True`。
- 如果此时 `parked.action == pause`，就升级为 `hide`。
- 需要核实：离开期间 VoidLink 不会再发出任何输入（`sendDummyEvent` 的 CADisplayLink 在后台应该已经停了）。如果仍有注入输入，就改用低级键盘/鼠标钩子，并检查 `LLKHF_INJECTED` / `LLMHF_INJECTED` 标志位，只统计物理输入。

**回来时**（同一台 iPad 的会话重新变为活跃，或断开后新连接的会话变为活跃）：
- 如果存在 `parked`、`local_use` 为假、进程还在 → 执行 `resume`：如果窗口在托盘里就从托盘还原，然后激活。之后清除 `parked`。
- 如果 `local_use` 为真 → 什么都不做，模拟器保持收起；清除 `parked`。
- 只撤销 agent 自己做过的动作。用户手动按 1/2 呼出过的，再执行 `resume` 也不会出问题，因为动作是幂等的。

## AHK：三个幂等动作 + 消息接口
- 抽出三个函数，共享 `FindMainAppWindow`、`ParkFocusThenHide` 和 RBTray 的 `WM_ADDTRAY` / `WM_REMTRAY` 逻辑：
  - `EmuPause(hwnd)`：如果主窗口可见并且是前台窗口，就创建一个**持续存在**的 1×1 透明工具窗口并激活它，用来接住焦点，让模拟器收到 `WM_KILLFOCUS` 而暂停。这个窗口一直保留到 `EmuResume`，否则焦点会弹回模拟器。如果模拟器本来就不在前台，则什么都不做。
  - `EmuHide(hwnd)`：移走焦点并收进托盘，也就是现有的 `ParkFocusThenHide`。如果已经在托盘里，则什么都不做。如果之前因 `EmuPause` 留下了接焦点的窗口，先销毁它。
  - `EmuResume(hwnd)`：如果在托盘里，就从托盘还原（沿用 `ToggleApp` 状态 C 的写法，包括 `AllowSetForegroundWindow` 和 `FlashWindow` 的兜底）；然后激活窗口，并销毁接焦点的窗口。
- 把 `ToggleApp` 改为调用这三个函数，热键 1/2 的现有行为保持不变。
- 消息接口：
  - `msg := DllCall("RegisterWindowMessage", "Str", "VoidLinkEmuCommand")`，`OnMessage(msg, handler)`。
  - 参数：`wParam` 为动词（1 = pause，2 = hide，3 = resume），`lParam` 为目标 pid。由 pid 找到 exe，再用 `FindMainAppWindow([exe])` 找到主窗口。
  - 返回值：1 表示执行了，0 表示没找到窗口。
  - 对 `A_ScriptHwnd` 调用 `ChangeWindowMessageFilterEx(..., msg, MSGFLT_ALLOW=1, 0)`，防止 AHK 以管理员身份运行时，普通权限的 agent 发来的消息被 UIPI 拦截。
  - handler 内部用 `SetTimer(() => ..., -1)` 异步执行动作，立即返回，不阻塞调用方的 `SendMessageTimeout`；返回值改为"已受理"。

## agent
- `config.json` 新增：
  - `emulators`：`["ryujinx.exe","ryujinx2.exe","eden.exe","yuzu.exe","azahar.exe"]`
  - `emulator_auto`：`true`
  - `ahk_window_title`：`"mac-keyboard-ahk-v2.ahk"`
- 定位 AHK 窗口：用 EnumWindows（包括隐藏窗口）找类名为 `AutoHotkey`、标题包含 `ahk_window_title` 的窗口；调用 `SendMessageTimeoutW(hwnd, msg, verb, pid, SMTO_ABORTIFHUNG, 1000)`。找不到时写日志。
- 会话状态，每个客户端连接一份：
  - 收到 `{"cmd":"session","state":"active"|"away"}` 时更新状态。
  - 连接断开、或客户端发过 ping 后超过 6 秒没有动静（复用音频租约 `LEASE_S` 的思路），都视为离开。
  - 只有发送过 `session` 命令的客户端参与，旧版 VoidLink 不受影响。
  - 用"会话拥有者"的思路处理多客户端：只按最近一次变为活跃的那个客户端来判定离开和回来。
- 每次采样记录"最近一次有客户端处于活跃状态时的采样"，供离开时使用。
- 显示器：激活的显示器数量来自 `enum_monitors()`。
- 状态 JSON 新增：
  - `monitors`：激活的显示器数量
  - `emulator_park`：`{"exe","action","local_use"}`，没有时为 null
  - 方便在 iPad 的日志里查看。
- README 补充：协议说明、配置项、Ryujinx 需要开启失焦暂停、AHK 需要运行。
- 日志前缀 `emu:`，写明每次离开、回来、升级、执行动作的原因。

## VoidLink
- `HostStateClient` 已有 `sendCommand:`，需要确认能否携带额外字段；不能的话就加一个能发送任意 JSON 的方法。
- 发送时机：
  - `applicationDidEnterBackground` → `away`
  - `applicationDidBecomeActive` → `active`
  - agent 连接建立、或重新连接成功时 → `active`
  - 退出串流时不需要专门发送：`hostAgent_stop` 关闭连接，agent 就当作离开。
- 设置：`d2a5731c` 引入的"16:9 游戏中退出或锁屏时发送"开关改为：
  - 改名为"离开时暂停模拟器"（英文 key：`Pause Emulator When Away`），默认开启。
  - 移到"通用"分组作为一行顶层设置，不再依赖手势指令是否绑定。
  - NSUserDefaults key 换成新的，例如 `EmulatorAutoPause`。旧的 `StreamGestureCommandOnLeave` 不再使用。
  - 开关关闭时不发送 `session` 命令。
- 原来的 `leaveCommand_*`（发送手势指令 + 延迟断流）整体删除，不保留回退。理由：不经过 agent 判断，盲发切换型快捷键本身就会出错；需要时可以手动用手势指令。同时删掉 `_leaveExitPending` 等配套状态，`returnToMainFrameAllowingBackgroundAutoResume:` 恢复为同步执行。
- 文案：`Pause Emulator When Away` 写入 `LocalizationHelper.m` 的 zh/en 兜底字典，中文"离开时暂停模拟器"。不加说明性副标题。

## 交付
- 子代理只负责实现和自检，不提交：
  - VoidLink 用 `docs/plans/2026-11-stream-gestures-and-sidebar.md` "交付流程"里的 xcodebuild 命令构建；
  - Python 用 `python3 -m py_compile`。
- 主会话随后做 Codex 审查和修复，然后分别提交两个仓库。Utilities 是私有仓库，提交后推送；VoidLink 不推送。最后打包 IPA。
- 需要用户在 PC 上测试：
  - Ryujinx 和 Eden 在"锁屏 → 解锁"后能否暂停并继续；
  - 大屏开着时是否收进托盘；
  - 离开期间碰一下 PC 键鼠后，回来模拟器是否保持收起；
  - 退出串流后重连能否继续；
  - agent 日志中 `emu:` 前缀的各条记录是否合理。
