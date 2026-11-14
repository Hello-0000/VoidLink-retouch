# 串流手势重构 + 设置侧栏重整 — 开发计划

已拍板（2026-11-14）：
- 右边缘短滑"显示/隐藏屏幕控件"并入手势表。
- 手势指令只做一个全局的。
- 强调色用系统蓝（`UIColor.systemBlueColor`）。
- 分两期实施，每期单独提交、单独打包 IPA。swap 改名移组随第二期完成。

仓库：`/Users/liuwei/Dev/Projects/VoidLink-retouch`，分支 `my-build`。ObjC + Swift 混编，部署版本 iOS 15（`UIMenu`、`UIButton.showsMenuAsPrimaryAction` 可直接用）。iPad 和 iPhone 各有一份 storyboard（`VoidLink/Base.lproj/iPad.storyboard`、`iPhone.storyboard`），两边都要照顾到。

新文案：英文 key，通过 `LocalizationHelper localizedStringForKey:` 取。中英文补进 `VoidLink/Localization/LocalizationHelper.m` 里的 fallback 字典（zhDict / enDict），不改 `Localizable.xcstrings`。

---

## 第一期：串流手势模型

### 1.1 现状（已核实）
| 功能 | 现在的实现 | 位置 |
|---|---|---|
| 打开设置 | `CustomEdgeSlideGestureRecognizer`；边缘取 `settings.slideToSettingsScreenEdge`（Core Data，默认 2 = Left），距离取 `slideToSettingsDistance`（默认 0.2） | `StreamFrameViewController.m` `configGestures`（约 686 行）→ `edgeSwiped` → `expandSettingsView` |
| 显示/隐藏 OSC | 右边缘写死两只识别器：`_rightEdgeToggleOscRecognizer`（被动）和 `_rightEdgeOverControlRecognizer`（earlyDecision，处理落在按钮类控件上的触摸），阈值约 15pt | 同上；`shouldReceiveTouch` 约 4632 行；`handleRightEdgeToggle:` → `toggleOscVisibility` |
| 打开工具箱 | **没有任何手势**。设置里的 `slideToToolboxScreenEdgeSelector` 只是 `slideToSettingsScreenEdgeChanged` 里的镜像假 UI。实际入口是 CMD widget 和快捷菜单 | `presentToolboxViewController` |
| 软键盘 | `CustomTapGestureRecognizer`，手指数取 `keyboardToggleFingers`（默认 3），轻点阈值 0.2s，挂在 `_streamFrameTopLayerView` 上；键盘弹起后用 `lowestTouchPointHeight` 抬高画面 | `StreamView.m` `refreshKeyboardToggleRecognizer:`（约 447 行）、`toggleKeyboard`、`keyboardWillShow:` |
| 布局编辑器 | `CustomTapGestureRecognizer`，手指数取 `oscLayoutToolFingers`（默认 4），`countsWithheldTouches = true`，仅在 `isOscLayoutToolEnabled` 时添加 | `configGestures` → `handleWidgetLayoutGesture` |
| 全屏控件 | widget 的 shape 为 `fullscreen`，运行时在 superview 上挂一个双击识别器，发送该 widget 的 `comboButtonStrings` 或 cmdString 键盘组合 | `OnScreenWidgetView.swift` `handleFullscreenDoubleTap`（约 1346 行） |

所有手势在侧栏关闭时由 `reConfigStreamViewRealtimeAndReloadSettings:` 先全部移除再重建，新逻辑也必须走这条路径。

### 1.2 数据模型
新建一个类（Swift `@objc` 或 ObjC 均可），作为唯一真相源，例如 `StreamGestureBindings`：

- 动作 `StreamGestureAction`：`settings`、`toolbox`、`softKeyboard`、`layoutEditor`、`toggleOsc`、`gestureCommand`。
- 触发方式 `StreamGestureTrigger`：`none`、`leftEdge`、`rightEdge`、`hold3`、`hold4`、`hold5`。
- 存储：NSUserDefaults 键 `StreamGestureBindings`，值为字典 {动作字符串: 触发方式字符串}。不新增 Core Data 属性。
- 手势指令内容：NSUserDefaults 键 `StreamGestureCommand`，格式和 widget 的 cmdString 一致；再加一个显示名，用于设置行的展示。
- 不变量：
  - 每个非 `none` 的触发方式最多属于一个动作。
  - `settings` 永远不能是 `none`。
  - 读取时如果发现违反不变量（数据损坏），按优先级修复：settings > toggleOsc > softKeyboard > layoutEditor > toolbox > gestureCommand。
- API：
  - `triggerForAction:`
  - `actionForTrigger:`
  - `assignTrigger:toAction:`：处理交换逻辑（见 1.6），返回被交换的那个动作，供 UI 做提示。
  - `commandString` / `commandDisplayName`
- 一次性迁移（标志键 `StreamGestureBindingsMigrationV1`）：
  - settings ← `slideToSettingsScreenEdge`：Left → `leftEdge`，Right → `rightEdge`，其他值 → `leftEdge`。
  - toggleOsc ← `rightEdge`；如果 settings 已经占了右边缘，则为 `none`。
  - softKeyboard ← `keyboardToggleFingers` 为 3/4/5 时映射成 `hold3/4/5`；为"关闭"时设为 `none`。关闭的存储值请到 `SettingsViewController.m` 约 2068 行和保存逻辑里确认。
  - layoutEditor ← `oscLayoutToolFingers` 为 3–5 且未被占用时映射；否则在 `hold4` 空闲时用 `hold4`，再不行就 `none`。
  - toolbox、gestureCommand 设为 `none`。
  - Core Data 里的旧属性保留，不删，但串流端不再读取它们。

### 1.3 多指长按识别器
新建 `MultiFingerHoldGestureRecognizer`，取代软键盘和布局编辑器的两只 `CustomTapGestureRecognizer`。以下这些**保持不动**：
- 相对模式下的双指右键（`RelativeTouchHandler.m:50`）
- 双指缩放和平移
- `readyToBringUpSoftKeyboardByToolbox` 的单指轻点

规格：
- 只接受手指（`allowedTouchTypes = Direct`），Pencil 不参与。
- **计数口径**：只数落在串流画面上的手指，包括被"OSC 开启时屏蔽串流触控"扣下的手指（等同 `includingWithheld:YES`）。按在 OSC 控件上的手指（旧 OSC 按钮层和 OnScreenWidgetView）**不计数**，也不能被这个识别器取消。可参考现有的 `streamTouchesForEvent:` / `streamTouchesFrom:` 和 `isOnScreenWidgetViewBeingPressed`，确认这套口径在三种触控模式下都成立。
- 状态机：
  - 手指数一变化就重新计时，并记下每根手指此刻的位置。
  - 任一手指偏移超过 12pt：本轮作废，所有手指抬起后才重新开始。
  - 手指数 ∉ {3,4,5}，或这个手指数没有绑定动作：不计时。
  - 计满 **1.5s** 时触发（Recognized），按触发时的手指数分发动作，并给一次 `UIImpactFeedbackGenerator(.medium)` 震动。
  - 每次按住只触发一次，所有手指抬起后才能再次触发。
- **进度环**：
  - 计时到 0.5s 时，在手指的质心处淡入。
  - 尺寸 56pt；底盘是黑色 35% 的圆；轨道白色 25%；进度弧白色，线宽 3pt，在 0.5s→1.5s 内从 0 填到满。
  - 触发后做一个约 0.15s 的缩放淡出；取消时直接淡出。
  - 加在最顶层的视图上，`userInteractionEnabled = NO`。
- **触发后撤销主机侧的触摸**：识别成功时依靠 `cancelsTouchesInView = YES`，让下层视图收到 `touchesCancelled`。要逐个确认 StreamView 在 native touch、absolute、relative 三种模式下的 `touchesCancelled` 都能让主机正确松开（触点 cancel、鼠标键抬起、拖拽结束）。做不到的话就补上。
- 识别期间（Possible 状态）不延迟、不取消任何触摸：`delaysTouchesBegan` 和 `delaysTouchesEnded` 都设为 NO，确保游戏输入没有延迟。
- 继续提供 `lowestTouchPointHeight`，`keyboardWillShow:` 的抬高画面逻辑改为读新识别器的值。键盘弹起后，同样的长按手势负责收起键盘；原来 `refreshKeyboardToggleRecognizer:` 里那套"弹起后切换手指数"的逻辑相应调整。
- 以下状态下不生效：布局编辑器已打开（`widgetToolOpened`）、设置侧栏已展开、工具箱或快捷菜单正在显示。
- 识别器挂在哪个视图（`self.view` 还是 `_streamFrameTopLayerView`）由实现者决定。硬性要求：三种触控模式下都能用；OSC 屏蔽串流触控时能用；"横屏·全屏游戏"场景下能用。
- 和 absolute 模式下的 scrollView 双指平移，以及 relative 模式下的各种多指手势都不能互相抢。

### 1.4 边缘手势
- 每条边（左、右）最多绑定一个动作，按绑定的动作来配置识别器：
  - `toggleOsc`：沿用现有那对识别器（被动 + over-control），阈值约 15pt，`shouldReceiveTouch` 里的分类逻辑原样保留。目前这套逻辑写死在右边缘，需要推广到"绑定了 toggleOsc 的那条边"。
  - `settings` / `toolbox`：沿用现在设置用的单只识别器，距离取 `slideToSettingsDistance`。
- 没有绑定动作的边不挂识别器。

### 1.5 动作分发与手势指令
- 新增一个分发方法，例如 `performStreamGestureAction:`：
  - settings → `expandSettingsView`
  - toolbox → `presentToolboxViewController`
  - softKeyboard → `toggleKeyboard`（StreamView 里现有的方法）
  - layoutEditor → `handleWidgetLayoutGesture`；要求 `isOscLayoutToolEnabled`，未启用时无动作
  - toggleOsc → `toggleOscVisibility`
  - gestureCommand → 执行 `StreamGestureCommand`
- 手势指令的执行：把 `handleFullscreenDoubleTap` 里"组合键按下 → 100ms 后抬起 / 键盘组合"这段逻辑抽成共享方法，widget 和手势共用。
- 全屏 widget 自己的双击功能完全不改。
- 双击不放进触发方式池。

### 1.6 设置 UI：手势分组
用代码重建"手势"分组的内容。删除 `softKeyboardGestureStack`、`slideToSettingsScreenEdgeStack`、`slideToToolboxScreenEdgeStack` 这三个控件，删除 `showCustomOswTip` 里输入手指数的弹窗，以及约 2164 行的手指数冲突校验。收藏模式（`_favoriteSettingStackIdentifiers`，约 1748 行）里的 id 也要同步更新。

```
手势
  打开设置          左边缘滑动 ▾
  打开工具箱        禁用 ▾
  软键盘            三指长按 ▾
  布局编辑器        四指长按 ▾
  显示/隐藏屏幕控件  右边缘滑动 ▾
  手势指令          禁用 ▾
     指令           <显示名> ›      ← 只在手势指令已绑定时显示，缩进 16pt
  边缘滑动距离      slider          ← 只在 settings 或 toolbox 绑在边缘上时显示（复用 slideToSettingsDistanceStack）
```
- 每行：标签在左；右边是 `UIButton`（`showsMenuAsPrimaryAction`），标题显示当前的触发方式，后面跟一个 `chevron.up.chevron.down`。
- 菜单项：左边缘滑动、右边缘滑动、三指长按、四指长按、五指长按、禁用。"打开设置"那一行没有"禁用"。当前项打勾（`state = on`）。
- 其他行里，"设置"当前占用的触发方式显示为 disabled。
- 交换：选中某个已被另一个（非设置）动作占用的触发方式时，那个动作换成本行原来的触发方式。被换掉的那一行做一次约 0.6s 的背景闪烁（系统蓝 15%），不弹 toast。
- 选择"指令"行：打开一个指令选择器，复用工具箱或 CommandManager 的指令列表，以及 widget 编辑器里选指令的方式。选定后保存 cmdString 和显示名。如果 widget 编辑器里有现成的选择器组件，直接复用。
- 文案（key 用英文，中文写进 zhDict）：
  - 动作：Open Settings / 打开设置，Open Toolbox / 打开工具箱，Soft Keyboard / 软键盘，Layout Editor / 布局编辑器，Show/Hide On-Screen Controls / 显示/隐藏屏幕控件，Gesture Command / 手势指令，Command / 指令，Edge Swipe Distance / 边缘滑动距离
  - 触发方式：Left Edge Swipe / 左边缘滑动，Right Edge Swipe / 右边缘滑动，3-Finger Hold / 三指长按，4-Finger Hold / 四指长按，5-Finger Hold / 五指长按，Off / 禁用
- 不加任何说明性的副标题或描述文字。
- 修改即时写入 `StreamGestureBindings`。串流中，侧栏关闭后经由 `reConfigStreamViewRealtime` 生效。

### 1.7 验收
- 首次启动后，原有行为保持不变：左边缘打开设置、右边缘切换 OSC、三指唤键盘（改为长按）、四指打开布局编辑器（改为长按）。
- 3/4/5 指长按满 1.5s 才触发；按住期间出现进度环；提前松手或手指移动都不会触发；按着 OSC 按键的手指不计数。
- 把工具箱设到右边缘后，右边缘打开工具箱；"显示/隐藏控件"自动换成工具箱原来的触发方式（禁用）。
- "设置"那一行不能选禁用；它占用的触发方式在其他行置灰。
- 手势指令：从布局里删掉全屏控件后，用绑定的手势仍然能发送指令。
- xcodebuild 构建通过。

---

## 第二期：设置侧栏重整 + swap 改名

### 2.1 分组（每组是一个 `MenuSectionView`，见 `VoidLink/MenuSectionView.m`；重组逻辑在 `SettingsViewController.m` 的 `layoutSections`，约 963 行）
1. **视频**：分辨率、帧率、码率、编码、HDR、YUV444、帧同步、帧队列
2. **画面**：屏幕比例、贴顶、画中画、外接显示器模式、重置比例记忆
3. **音频**：声音跟随、PC 播放、声道
4. **触控**：触控模式；指针速度 3 个 slider 作为子项（只在相对模式下显示）；防手掌误触
5. **屏幕控件**：启用屏幕控件（`onScreenWidgetStack`）、OSC 开启时屏蔽串流触控（`installStreamTouchBlockControl`）
6. **手柄**：模拟手柄类型、多手柄、实体手柄组合键、实体手柄交换 A/B、实体手柄交换 X/Y；陀螺仪模式，其下的灵敏度、映射到、反转俯仰、反转偏航作为子项（只在陀螺仪开启时显示）
7. **Apple Pencil**：Pencil 按住模式、滚动跟随笔尖，以及 `layoutSections` 约 1022 行循环里加进来的 Pencil 相关 slider（请逐个核对归属）
8. **手势**：第一期的手势表
9. **鼠标与键盘**：本地鼠标指针、反转滚轮、Citrix X1、软键盘工具栏
10. **通用**：统计浮层、性能图、后台会话计时、解锁方向、优化游戏设置
11. **实验**：保持原样

每组的图标沿用现有风格。新增的组："画面"用 `rectangle.on.rectangle`，"屏幕控件"用 `circle.grid.2x2`，"手柄"用 `gamecontroller`，"Pencil"用 `pencil.tip`，"鼠标与键盘"用 `keyboard`。

收藏模式和全部模式都要正常；条件显示的项目（`hdrSupported`、iPad 专有项等）原有的条件保持不变。

### 2.2 层级与对齐
- 层级只有三层：分组标题 → 行 → 依赖子项。子项缩进 16pt，父项关闭时隐藏（不是置灰）。
- 行只有两种：
  - **单行**：标签在左，控件在右（开关、下拉、数值），最小高度 44pt，控件垂直居中。
  - **双行**：第一行是标签加右侧数值，第二行是全宽的 slider 或 segmented。
- 各行的左右内边距统一为 16pt，ⓘ 统一紧跟在标签后面。
- segmented 如果超过 3 个选项，或在 iPhone 竖屏宽度下文字被截断，就改成第一期那种下拉按钮。改了哪些，在汇报里列出来。

### 2.3 颜色（只作用于设置侧栏，不改全局的 `appPrimaryColor` / `appSecondaryColor` 的其他调用方）
在 `ThemeManager` 里新增一组侧栏 token（动态颜色，跟随深浅模式）：

| token | 深色 | 浅色 |
|---|---|---|
| sidebarBackground | #111214 | #F2F2F7 |
| sidebarCard | #1C1D20 | #FFFFFF |
| sidebarControlFill（开关关闭态、slider 轨道、segmented 底） | #2C2D31 | #E5E5EA |
| sidebarSeparator | 白色 8% | 黑色 8% |
| sidebarTextPrimary | #F2F2F5 | #000000 |
| sidebarTextSecondary | #9A9BA3 | #6C6C70 |
| accent | systemBlue | systemBlue |

- 分组卡片：每组的行放在一张 `sidebarCard` 圆角卡片里（圆角 12，左右外边距 12）。分隔线只出现在卡片内部的行与行之间，左侧内缩 16pt，高度为 1 物理像素。
- 开关：`onTintColor = systemBlue`；关闭态用 `sidebarControlFill` 作底色，圆角取高度的一半。
- slider：`minimumTrackTintColor = systemBlue`，`maximumTrackTintColor = sidebarControlFill`，thumb 白色。
- segmented：背景 `sidebarControlFill`，`selectedSegmentTintColor = systemBlue`。用 `setTitleTextAttributes:forState:` 设置文字颜色：normal 用 `sidebarTextPrimary`，selected 用白色。
- **修掉根因**：`updateThemeForLabels:` 不能再递归进 `UISegmentedControl`、`UIButton` 等控件内部去改标签颜色。`updateThemeForSelectors:` 和 `updateThemeForSliders:` 改用上面的 token，不再用混了灰的 `appSecondaryColor`。
- 侧栏里其他零散的硬编码颜色（例如约 1241 行的 `colorWithRed:0.5 green:0.5 blue:1 alpha:0.35`、拖拽态等）一并换成 token。

### 2.4 swap 改名
- 文案改为 "Controller: Swap A/B" / 实体手柄：交换 A/B，"Controller: Swap X/Y" / 实体手柄：交换 X/Y，放进"手柄"分组。
- 行为不变：只作用于实体手柄（`ControllerSupport.m:1747`），OSC 以布局为准。

### 2.5 验收
- 深浅两种模式下：选中 segment 一律白字蓝底；开关关闭态、slider 轨道和卡片背景能区分开；分隔线不脏。
- 所有行左对齐一致；子项随父项显示或隐藏。
- iPad 和 iPhone、收藏模式和全部模式、串流中打开侧栏和主界面打开设置，都正常。
- xcodebuild 构建通过。

---

## 交付流程（每期）
1. 实现者完成代码，用下面的命令做构建检查（不打包、不提交）：
   ```sh
   xcodebuild -quiet -project VoidLink.xcodeproj -scheme VoidLink -configuration Debug -destination 'generic/platform=iOS' -clonedSourcePackagesDirPath Build/SourcePackages -packageAuthorizationProvider netrc -skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile SYMROOT="$PWD/Build/Products" CODE_SIGNING_ALLOWED=NO build
   ```
2. 主会话跑 Codex 审查，修掉关键问题。
3. 提交（不推送）。
4. 运行 `BuildScripts/package-debug-ipa.sh`，报告 IPA 的路径、大小和 SHA256。
