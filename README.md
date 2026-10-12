# MikuTools

沿用 mikuai 品牌的自用 Mac 工具集，与「初研 AI」同系列。支持 macOS 14 及以上，无第三方依赖。

- Finder Sync 扩展：一级右键菜单「在 vscode 中打开」「在 iTerm2 中打开」，图标从本机应用读取。未安装对应应用时菜单项置灰。
- WidgetKit 原生系统监控小组件：可以加入桌面和通知中心，支持系统的小号、中号尺寸。中号保持 CPU / RAM / DISK / NET 的 1×4 横向排列，前三列为白色半圆 Gauge，NET 显示下载和上传速度；小号为 2×2 排列，第一行 CPU / RAM，第二行 DISK / NET。两种尺寸均只显示四项指标，内容居中，不显示采样时间。

App 图标由项目根目录的 `favicon.ico` 转换为 `App/AppIcon.icns`，随 App 打包。工程名和 Scheme 仍为 `mac-tools`；应用名称为 **MikuTools**。

## 添加原生小组件

1. 如果旧版悬浮监控面板仍在显示，先右键面板选择「退出 mac-tools」。
2. 启动新版 App：

```sh
open /Applications/MikuTools.app
```

新版主 App 没有 Dock 图标或悬浮窗口；启动会请求小组件刷新。建议将 `MikuTools.app` 放到 `/Applications` 或 `~/Applications` 后使用，保持位置固定。

3. **加入桌面**：右键桌面空白处 → 编辑小组件，在列表中搜索 **MikuTools**，将「系统监控」拖到桌面。
4. **加入通知中心**：点击菜单栏右上角日期时间 → 滚到底部 → 编辑小组件，搜索 **MikuTools**，添加「系统监控」到右侧通知中心。

在图库中选择小号或中号；已有小组件也可右键切换尺寸。

位置、移除和跨桌面的显示行为由 macOS 管理。点击小组件会通过主 App 请求刷新，不会打开监控窗口。

如果系统尚未列出小组件，可手动注册构建产物（如果已移动 App，使用实际安装路径）：

```sh
pluginkit -a /Applications/MikuTools.app/Contents/PlugIns/WidgetExtension.appex
```

然后退出并重新打开「编辑小组件」。添加方法可参考 [Apple 的小组件使用说明](https://support.apple.com/guide/mac-help/add-and-customize-widgets-mchl52be5da5/mac)。

## 刷新与数值含义

主 App 常驻后，CPU、RAM、主要网络接口的收发速度每 1 秒采样并写入 App Group 共享 `UserDefaults`；磁盘使用率每 15 秒采样。网络速度只在主 App 根据连续两次累计字节差值和实际时间差计算。主 App 用一个串行计时器每 2 秒调用 `WidgetCenter.shared.reloadTimelines(ofKind:)`，尽可能让小组件显示 2～5 秒级的新数据。

**2 秒是请求频率，不是显示保证**。WidgetKit 可以节流、合并或延迟请求，尤其是主 App 在后台时。参见 [Apple 的刷新说明](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)。主 App 通过活动声明避免采样被 App Nap 暂停，同时允许系统正常睡眠。

Widget Extension 只读取共享快照，不调用 Mach、磁盘或网络采样 API；TimelineProvider 每次只生成一个当前 Entry，策略为 `.never`。百分比和网络速度使用 `.contentTransition(.numericText())` 与短动画过渡。主 App 退出时刷新请求停止，缓存和小组件保留最后一次采样值；缓存还不存在时各指标显示 `--`。

统一的 App Group identifier 是 `group.local.mikutools.monitor`，主 App 和 Widget Extension 的 entitlements 均已配置。共享快照以一份 Codable property list Data 存放，避免不同指标读到不同采样时刻。关闭主 App 时显式刷新持久化缓存并请求一次最终 Widget 刷新。

- CPU：Mach 累计 tick 的采样差值。
- RAM：Mach VM 统计，计入有线、应用和物理压缩页，扣除可回收文件页与 purgeable 页，是使用率估算。
- DISK：`/` 卷的 `(总容量 − 可用容量) / 总容量`，不表示读写速度。
- NET：SystemConfiguration 获取 IPv4 的 PrimaryInterface，未找到时查 IPv6；只读取该接口的 `getifaddrs` 收发字节，不累加网卡、VPN、桥接等接口。速度采用十进制 B/s、KB/s、MB/s、GB/s。

暂时无法读取的指标显示 `--`。小组件图库的预览使用示例数值，实际添加后使用真实采样数据。

## 构建

打开 `mac-tools.xcodeproj`，选择 `mac-tools` Scheme，运行。工程包含三个 Target：主 App、FinderExtension、WidgetExtension，两种扩展自动嵌入主 App。

```sh
xcodebuild -project mac-tools.xcodeproj -scheme mac-tools -configuration Release -derivedDataPath build build
```

构建产物为 `build/Build/Products/Release/MikuTools.app`。退出正在运行的旧版后，用它替换 `/Applications/MikuTools.app`，再从「应用程序」启动。固定使用安装位置，避免同时运行构建目录中的旧副本。若图库仍显示旧名或旧尺寸，关闭并重新打开「编辑小组件」，移除旧小组件后重新添加。

工程默认使用本机 ad-hoc 签名；如要使用自己的开发者签名，在三个 Target 的 Signing & Capabilities 中选择同一个 Team，并启用 Automatically manage signing。

本机三个 Target 的 Xcode 构建及嵌套签名检查已通过。与小组件相同 App Sandbox 权限下的 CPU、RAM、DISK、NET 采样检查通过。实际小组件布局仍需在桌面／通知中心添加后查看。

1.4 修复了 Finder 菜单点击无响应：菜单动作从 `FIFinderSyncController` 读取当前选择，并保留菜单创建时的路径作为回退，不依赖跨进程无法可靠保留的 `NSMenuItem.representedObject`。打开请求失败时会显示错误信息。

1.5 修复了 Finder 扩展被拒绝打开所选文件的沙箱权限错误：VS Code 和 iTerm2 均由扩展通过 URL 传递路径给主 App，再由主 App 执行打开。VS Code 多选的所有路径在一个请求中传递，并用一次 NSWorkspace 调用打开。已安装到 `/Applications`；用户已实际确认两个 Finder 菜单均能正常打开同一个目录。

本机曾因改名和移动 App 后，小组件服务继续绑定已删除的 `mac-tools.app` 构建路径，造成图库仍使用旧版本。此次已清理旧构建路径注册和进程，重新注册 `/Applications/MikuTools.app` 并重启小组件服务；系统日志确认从安装位置启动扩展，成功读取小号、中号两个尺寸。若以后移动 App 后遇到同类问题，先退出旧副本、启动安装位置中的 App，再重新打开「编辑小组件」；不要同时保留正在运行的旧构建副本。

## 启用 Finder 扩展

启动一次 App，然后在系统设置 → 通用 → 登录项与扩展 → Finder 中启用 **MikuTools Finder**。

如果系统尚未列出扩展，可手动注册实际安装位置下的扩展，例如：

```sh
pluginkit -a /Applications/MikuTools.app/Contents/PlugIns/FinderExtension.appex
```

随后重新打开系统设置并启用扩展。菜单仍未出现时，可通过 Apple 菜单 → 强制退出 → Finder → 重新开启，重启 Finder。

扩展观察 `/` 下的目录，文件、文件夹、Finder 窗口空白区域均支持。VS Code 多选使用一次 NSWorkspace 请求打开全部项目。iTerm2 在文件的父目录或选中的文件夹中新建默认 Profile 窗口；使用默认本地 zsh/bash 等 POSIX shell。没有额外的「mac-tools」二级菜单。

## 权限与文件

- Finder 功能需要手动启用扩展；第一次点击「在 iTerm2 中打开」时，允许 **MikuTools 控制 iTerm2**。如之前拒绝过，在系统设置 → 隐私与安全性 → 自动化中开启。
- 原生小组件不需要辅助功能、录屏或完全磁盘访问权限，需要已配置的 App Group 共享缓存；Widget 已移除网络客户端权限，也不会执行网络采样或连接外部网络。
- 若打开桌面、文稿、下载等受保护目录，macOS 可能按实际访问情况要求相应应用的「文件与文件夹」权限。

`App/` 管理启动、刷新请求、VS Code 打开和 iTerm2 AppleScript；Finder 扩展通过 `mac-tools://open-vscode?path=…` 或 `mac-tools://open-iterm?path=…` 将路径交给主 App，多选使用重复的 `path` 参数。URL 编码、shell 单引号转义、AppleScript 字符串转义分别处理，支持空格、中文、引号、反斜杠、shell 特殊字符和含控制字符的路径。

`WidgetExtension/` 定义 WidgetKit 扩展、TimelineProvider 和刷新策略；`SystemMonitor/` 保留共享快照、常驻采样器、视图及几个简单的原生指标读取文件；只有快照和视图编入 Widget，采样器及指标读取文件仅编入主 App。旧 NSPanel 实现已移除。

1.6 增加主 App 常驻采样、App Group 缓存、每 2 秒主动请求刷新和数字过渡。已通过 18 秒的采样／刷新周期检查；真实安装版的独立沙箱读取进程在 12 秒内看到 13 次缓存更新，系统日志记录了约每 2 秒的 WidgetCenter 请求。主 App 实际退出后，五项指标和采样时间在 3 秒检查期间保持完全相同，检查后已恢复运行。实际小组件显示频率仍取决于 WidgetKit。

1.7 将 Finder 菜单的应用查找和图标读取移到扩展启动后的后台预加载，并在内存中缓存渲染好的 16 pt 图标。右键菜单回调只读取缓存，不再同步调用 Launch Services 或 Icon Services；首次缓存尚未准备好时菜单可用，图标会在后续打开菜单时出现。不另存图标文件。

1.8 移除小组件的采样时间和底部等待提示。中号四列整体垂直居中、标签对齐；小号两行等高分配空间。采样时间仍保留在共享快照中，不影响刷新或数据持久化。
