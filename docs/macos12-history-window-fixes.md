# macOS 12 历史窗口布局与悬停选中修复记录

## 背景

在 `chore/macos12-support` 分支恢复 macOS 12 支持后，历史展示窗口虽然已经能正常打开和显示内容，但和参考版本 `/Users/opera/Documents/Clipbook` 相比，仍然出现了几类明显的运行时问题。

这份文档专门记录这批问题的现象、排查结论、已经落地的修复，以及后续还需要继续观察的点。

## 问题现象

### 1. 历史展示窗口位置和尺寸异常

用户反馈的典型表现是：

- 历史展示界面刚打开时看起来基本正常
- 过一会儿后，列表、footer、预览相关区域会出现错位
- 有时会出现“布局塌缩”或高度计算不对的问题
- macOS 12 版本比参考版本更容易出现窗口内容位置变化

这个现象说明问题不只是“初始布局算错”，更像是界面在后续状态更新后又被错误地重新测量了一次。

### 2. 历史列表区域的布局不稳定

用户在多轮测试里反馈过：

- 滚动区域可见高度不对
- 列表中间区域和顶部、底部辅助区域之间的分配不稳定
- 某些场景下会出现看起来“先正常、后错位”的变化

### 3. 鼠标悬停时蓝色选中条跟手偏慢

当前剩余问题主要集中在这里：

- 鼠标在历史展示区域上下移动时
- 蓝色选中条会跟着走，但响应显得偏慢
- 视觉上像是“事件收到了，但更新被拖住了”

## 根因判断

### 1. 尺寸读取链路互相污染

最可疑的问题点在 `HeightReaderModifier.swift`。

原来的实现依赖共享的尺寸读取机制，多个区域如果复用同一条偏好值链路，就可能在异步刷新后互相覆盖尺寸结果。结合“刚开始正常，过一会儿出问题”的现象，这类问题非常符合当前症状。

### 2. macOS 12 下列表布局对尺寸策略更敏感

`HistoryListView.swift` 里历史列表本身、顶部区域、底部区域、滚动区域之间存在一组比较细的高度分配关系。新系统上可能还能凑合工作，但在 macOS 12 上更容易因为尺寸读回时机不同而出现错位。

### 3. 悬停选中链路里有多余延迟

悬停选中原本带有“键盘导航 -> 鼠标导航”的切换过程。这个切换如果依赖后续的鼠标移动事件再完成，就会让蓝色选中条看起来慢半拍。

### 4. 全局鼠标移动事件触发了不必要的高频刷新

`ContentView.swift` 中有一层全局 `onMouseMove`。原先它在鼠标每次移动时都会重复写入：

- `appState.navigator.isKeyboardNavigating = false`

即使这个值已经是 `false`，也仍然会持续触发状态写入和视图刷新。这类高频无效更新很容易让列表悬停高亮的跟手感变差。

## 已落地修复

### 1. 修复尺寸读取互相覆盖

文件：

- `Clipbook/Views/HeightReaderModifier.swift`

调整内容：

- 去掉共享 `PreferenceKey` 风格的尺寸读取方式
- 改成每个视图局部使用 `GeometryReader`
- 使用 `.task(id: proxy.size)` 在尺寸真实变化时才回写目标状态

修复目标：

- 避免 header、footer、列表、预览等不同区域把彼此的尺寸结果覆盖掉
- 降低“初始正常，稍后布局突然错位”的概率

### 2. 收紧历史列表区域的布局策略

文件：

- `Clipbook/Views/HistoryListView.swift`

调整内容：

- 移除了会放大布局不稳定性的 `.fixedSize(...)`
- 去掉当前本地 SDK / Xcode 不能稳定编译的 `contentMargins(..., for: .scrollIndicators)`
- 保持滚动区、顶部区域、底部区域在 macOS 12 下可用的写法

修复目标：

- 让历史列表容器回到更接近稳定版本的布局行为
- 减少滚动区和辅助区域之间的异常高度竞争

### 3. 让悬停选中立即生效

文件：

- `Clipbook/Views/HoverSelectionModifier.swift`

调整内容：

- 鼠标移入列表项时，如果当前不是多选状态，直接切换到鼠标驱动的选中
- 清掉 `hoverSelectionWhileKeyboardNavigating`
- 立即把 `isKeyboardNavigating` 设为 `false`
- 直接调用 `selectWithoutScrolling(id:)`

修复目标：

- 去掉“还要再等一次 mouse move 才真正切过去”的额外延迟
- 让蓝色选中条在鼠标进入某一项时立即跟上

### 4. 避免鼠标每移动一次都触发一次无效刷新

文件：

- `Clipbook/Views/ContentView.swift`

调整内容：

- 给全局 `onMouseMove` 增加保护判断
- 只有当前确实处于键盘导航状态时，才把 `isKeyboardNavigating` 切成 `false`

修复目标：

- 避免高频重复写入同一个状态
- 降低鼠标经过历史列表时整块内容反复重绘的压力
- 改善蓝色选中条的跟手感

## 当前代码变更清单

截至本次记录，和这批问题直接相关的本地修改包括：

- `Clipbook/Views/HeightReaderModifier.swift`
- `Clipbook/Views/HistoryListView.swift`
- `Clipbook/Views/HoverSelectionModifier.swift`
- `Clipbook/Views/ContentView.swift`

## 本地交付记录

本次已经重新构建本地测试包，并替换到用户测试位置。

构建来源：

- `build-local-package/Build/Products/Release/Clipbook.app`

替换目标：

- `/Users/opera/Documents/Clipbook.app`

本次替换前执行过：

- 结束运行中的 `Clipbook`
- 删除旧的 `/Users/opera/Documents/Clipbook.app`
- 对新产物执行 ad-hoc 签名
- 再移动到 `Documents`

## 本次验证结果

- 本地 `Release` 构建已通过
- 当前交付包仍然是 `x86_64 arm64` 通用二进制
- 用户反馈“现在好点了”，说明布局问题已明显缓解
- 当前剩余主要观察点是：历史列表里鼠标上下移动时，蓝色选中条是否已经足够跟手

## 后续待观察

### 1. 蓝色选中条是否还有明显延迟

如果这次 `ContentView.swift` 的高频刷新收紧后仍然偏慢，下一步优先检查：

- `Clipbook/Views/MouseMovedViewModifer.swift`
- `Clipbook/Views/ListItemView.swift`
- `Clipbook/Observables/NavigationManager.swift`

### 2. 是否仍存在“先正常、后错位”的迟发型布局问题

如果继续出现，优先复查：

- 尺寸读回时机
- 历史列表和预览区之间的状态联动
- 预览自动展开链路是否触发了新的尺寸震荡

### 3. 用户确认稳定后再提交

这批修复建议在用户确认“布局稳定、蓝条跟手正常”后再统一提交，避免把半成品验证状态直接推上远端。

