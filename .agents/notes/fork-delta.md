---
status: active
superseded_by:
supersedes:
模块: core, ui
---

# 与上游 xterm.dart 的已知故意分歧登记（Fork Delta）

## 一句话结论

登记本仓库针对 Conduit / Conduit-feat 消费端场景所做的全部定制与上游故意分歧，明确禁止未经指示向上游对齐回退。

## 背景

`conduit_vt` 是为 Conduit 终端定制的 Flutter 终端模拟器库，fork 自 upstream [`xterm.dart`](https://github.com/TerminalStudio/xterm.dart)。为了满足移动端交互、Mosh 预测回显和现代化终端转义需求，本仓引入了多项上游暂未合并或属于特化定制的功能。

## 决策

以下为本仓与上游的已知故意分歧清单：

### 1. Mosh 预测回显与临时 Cell 覆盖层 (`TerminalCellOverlay`)
- **实现位置**：`lib/src/ui/terminal_view.dart`, `lib/src/terminal.dart`
- **分歧内容**：引入 `TerminalCellOverlay`，支持在终端缓冲区上层直接绘制临时单元格而不修改终端底层 Buffer 状态；支持 `erase` 标志以支持预测删除，支持 `opacity` 不透明度控制。
- **状态暴露**：增加光标绝对行 (`absoluteCursorRow`)、视口度量 (`viewMetrics`)、Alternate-buffer 激活状态与单元格字符编码等访问器，供外部预测回显定位使用。

### 2. OSC 8 超链接转义序列支持
- **实现位置**：`lib/src/core/escape/`, `test/hyperlink_test.dart`
- **分歧内容**：在上游基础转义解析器中增加了对 OSC 8 超链接序列（`\x1b]8;;url\x1b\` / `\x1b]8;;\x1b\`）的完整解析与终端单元格超链接属性关联。

### 3. 移动端键盘、输入法（IME）与手势特化控制
- **实现位置**：`lib/src/ui/terminal_view.dart`, `lib/src/ui/custom_text_edit.dart`
- **分歧内容**：
  - `suppressKeyboardOnFocus`：获焦时阻止系统软键盘自动弹出，交由外部工具栏控制。
  - `keepKeyboardHiddenOnTap`：点击终端视口时不主动唤起软键盘。
  - `showSoftKeyboard` / `hideSoftKeyboard` / `dismissSoftKeyboard`：暴露明确的软键盘与 IME 连接生命周期控制入口。
  - 匿名 FocusNode 首次点击与焦点丢失时保持待处理输入 Intent 等边缘修复。

### 4. Alternate Buffer 触控滚动模拟与事件 Clamp
- **实现位置**：`lib/src/ui/terminal_view.dart`, `lib/src/ui/pointer_input.dart`
- **分歧内容**：
  - `simulateScroll`：在 Alternate Screen（如 vim、htop、less）下，触控滚动模拟发送上下方向键（Arrow Up / Down），而非仅依赖上游 SGR 鼠标滚轮报告。
  - `onTouchScroll`：提供触控滚动事件回调与 Primary Screen 接管能力。
  - 触控/鼠标事件坐标严格 clamp 至视口几何边界，防止越界计算异常。

### 5. CSI 3J 历史缓冲区清除控制
- **实现位置**：`lib/src/terminal.dart`, `lib/src/core/buffer/`
- **分歧内容**：增加 `keepScrollbackOnErase` 标志，可选择性忽略 `CSI 3J` 清除回滚历史命令，满足部分移动会话保留历史输出的需求。

### 6. 延迟调整尺寸（Deferred Resize）
- **实现位置**：`lib/src/terminal.dart`
- **分歧内容**：增加 deferred resize 机制与显式 `commit` API，在移动端容器动画伸缩期间推迟 resize 重排计算，避免布局抖动。

### 7. 其他待确认项
- 字体排版与段落缓存细微调优（待维护者确认）。

## 被放弃的方案（必填）

- **完全向上游 xterm.dart 主干对齐并移除定制**：被放弃。上游主要面向通用 Flutter 桌面/基础移动场景，缺乏 Conduit 深度依赖的 Mosh 预测覆盖层和移动端软键盘精细管理 API，若强行对齐会导致下游 Conduit / Conduit-feat 核心功能中断。

## 来源

- Git 提交历史（`855702f`、`777ac1f`、`5e58fbd`、`7a36d61`、`b48b0b1`、`0fbdf63`、`6f21235` 等）
- Conduit / Conduit-feat 依赖消费需求
