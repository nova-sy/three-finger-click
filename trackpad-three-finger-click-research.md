# macOS 三指触摸板 Click 自用工具可行性调研

## 目标

评估在 macOS 15.7 上实现一个纯自用小工具的可行性：识别触摸板三指同时 click，并绑定到自定义动作，例如发送快捷键、模拟鼠标中键、运行脚本、打开应用或触发本地命令。

本调研不依赖 Mos 现有体系，不考虑 App Store 分发，也不要求长期产品级兼容。

## 环境基线

本机核对环境：

- macOS: 15.7.7
- Xcode: 26.2
- macOS SDK: 26.2

公开 AppKit 和私有 MultitouchSupport 的状态不同：

- AppKit 公开 API 可以在应用自己的 view 内识别多指 click。
- 系统级全局识别三指 click，公开 AppKit API 不够。
- 私有 `MultitouchSupport.framework` 在 macOS 15.7.7 上仍可通过 `dlopen` 访问关键符号。

## 公开 API 调研

### NSClickGestureRecognizer

当前 SDK 中 `NSClickGestureRecognizer` 具备多触点 click 配置：

```objc
@property NSInteger numberOfTouchesRequired API_AVAILABLE(macos(10.12.2));
```

配合 `numberOfClicksRequired` 和 `buttonMask`，可以表达“三指 + 主键 click”：

```swift
let recognizer = NSClickGestureRecognizer(target: target, action: #selector(handleClick))
recognizer.numberOfTouchesRequired = 3
recognizer.numberOfClicksRequired = 1
recognizer.buttonMask = 0x1
view.addGestureRecognizer(recognizer)
```

但 `NSGestureRecognizer` 的事件范围是绑定 view 及其 subviews 的 hit-tested 事件，不是全局输入源。因此它适合做窗口内测试、偏好设置面板、调试 UI，不适合做后台全局快捷动作工具。

Apple 文档：

- NSClickGestureRecognizer: https://developer.apple.com/documentation/appkit/nsclickgesturerecognizer
- NSGestureRecognizer: https://developer.apple.com/documentation/appkit/nsgesturerecognizer
- NSEvent: https://developer.apple.com/documentation/appkit/nsevent

### NSEvent Global Monitor

`NSEvent.addGlobalMonitorForEventsMatchingMask` 可监听其他应用事件副本，但它不能修改或消费事件，也不能可靠提供触摸板 click 对应的 finger count。它不适合作为三指 click 的核心识别源。

### CGEventTap

`CGEventTap` 可以全局监听或拦截鼠标事件，例如 `leftMouseDown` / `leftMouseUp`。它适合判断物理 click 的时序并消费原始点击，但 CGEvent 本身通常不能稳定提供“当前有三根手指触摸触摸板”的信息。

因此公开 API 组合的结论是：

- view 内三指 click：可行。
- 全局三指 click：仅靠公开 AppKit/CoreGraphics 不可靠。

## 私有 MultitouchSupport 调研

macOS 15.7.7 上，`/System/Library/PrivateFrameworks/MultitouchSupport.framework` 的磁盘文件表现为 broken symlink，但运行时仍可通过 `dlopen` 打开，关键符号可通过 `dlsym` 获取：

- `MTDeviceCreateList`
- `MTRegisterContactFrameCallback`
- `MTDeviceStart`
- `MTDeviceStop`
- `MTDeviceRelease`

这说明对自用工具而言，可以采用私有 MultitouchSupport 读取触摸板 contact frame，获得当前 finger contact 数量和位置，再与 CGEventTap 捕获的 click 事件组合判断“三指同时 click”。

注意：这是私有 API，不适合 App Store，不适合产品化承诺，也可能在系统更新后失效。

## 推荐架构

推荐拆成三个小模块：

1. `TouchTracker`
   - 通过 `MultitouchSupport.framework` 注册 contact frame callback。
   - 维护当前 active touches。
   - 输出当前 finger count、触点位置、最近更新时间。

2. `ClickTap`
   - 通过 `CGEventTap` 监听 `leftMouseDown` / `leftMouseUp`。
   - 在 click down/up 时读取 `TouchTracker` 当前状态。
   - 判断是否满足三指 click 条件。
   - 可选择消费原始 click。

3. `ActionRunner`
   - 执行动作。
   - 第一版建议只支持一种固定动作，例如模拟 middle click 或发送固定快捷键。
   - 后续再扩展配置文件、菜单栏 UI 或多动作映射。

## 识别逻辑建议

第一版可以采用保守状态机：

```text
touch frame 更新:
  记录 activeTouchCount、touch positions、timestamp

leftMouseDown:
  如果 activeTouchCount == 3 且 touch 数据新鲜:
    标记 candidate
    记录 down 时间、鼠标位置、触点位置
    如果配置为 down 触发，立即执行动作
    如果配置为消费原始点击，返回 nil

leftMouseUp:
  如果 candidate 仍有效:
    检查 duration、鼠标移动距离、触点数量变化
    如果通过，执行动作
    清理 candidate
    如果配置为消费原始点击，返回 nil
```

建议阈值：

- touch 数据新鲜度：50-100 ms。
- click 最大持续时间：300-500 ms。
- 鼠标最大移动距离：5-10 px。
- touch count 必须是 3，或允许短时间内 2/3 抖动。

是否在 down 触发还是 up 触发取决于动作类型：

- 发送快捷键、运行脚本：up 触发更稳，误触更少。
- 模拟 middle click down/up：需要保留 down/up 配对。
- 替代鼠标点击：需要消费原始 left click，状态处理必须更谨慎。

## 动作方案

第一版建议只做一个动作，减少变量。

可选动作：

- 模拟 middle click。
- 发送固定键盘快捷键，例如 `Command + Option + Control + Space`。
- 执行 shell 命令。
- 打开应用或 URL。
- 运行 AppleScript。

如果目标是通用绑定，建议用配置文件：

```json
{
  "trigger": "trackpad.threeFingerClick",
  "consumeOriginalClick": true,
  "action": {
    "type": "keystroke",
    "keyCode": 49,
    "modifiers": ["command", "option"]
  }
}
```

## 权限

通常需要 Accessibility 权限，尤其是以下场景：

- 创建可拦截事件的 `CGEventTap`。
- 消费原始 mouse event。
- 发送合成键盘或鼠标事件。

如果只读 MultitouchSupport contact frame，权限需求可能较少，但最终工具通常仍会因为动作执行需要 Accessibility。

## 风险

主要风险：

- `MultitouchSupport.framework` 是私有 API，系统更新可能破坏。
- contact struct 需要按现有社区经验或实测确认，字段布局可能变化。
- 和系统三指手势冲突，例如 Look Up、三指拖移、Mission Control、Spaces。
- 消费原始 click 时必须保证 down/up 配对，否则可能造成鼠标状态异常。
- 外接 Magic Trackpad、内置触摸板、不同硬件代际可能有差异。
- 多显示器、睡眠唤醒、设备热插拔都需要额外处理。

对纯自用工具，这些风险可接受；对公开发布工具，需要显著提高测试和兼容投入。

## MVP 实施顺序

1. 写命令行探针，只打印 MultitouchSupport contact frame 的 touch count。
2. 验证三指触摸、三指 click、三指 drag、两指 click 是否能区分。
3. 增加 CGEventTap，打印 leftMouseDown/up 时的 touch count。
4. 做三指 click 状态机，不执行动作，只输出日志。
5. 增加一个固定动作，例如模拟 middle click。
6. 增加 Accessibility 权限提示和失败诊断。
7. 稳定后再做菜单栏、LaunchAgent 或配置文件。

## 推荐结论

纯自用小工具可行。推荐路线是：

```text
MultitouchSupport 读取三指状态
        +
CGEventTap 捕获/拦截 click
        +
状态机判断三指 click
        +
CGEventPost / shell / AppleScript 执行动作
```

不建议第一版做成完整通用绑定平台。先做固定动作、日志充分的最小工具，确认在当前 macOS 15.7 和个人触摸板设置下识别稳定，再逐步扩展。
