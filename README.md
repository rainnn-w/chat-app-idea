# ChatMemory

[![CI](https://github.com/rainnn-w/chat-app-idea/actions/workflows/ci.yml/badge.svg)](https://github.com/rainnn-w/chat-app-idea/actions/workflows/ci.yml)
[![License: MIT](https://github.com/rainnn-w/chat-app-idea/blob/main/LICENSE)](https://github.com/rainnn-w/chat-app-idea/blob/main/LICENSE)

这是一个开源、本地优先的聊天记忆整理器，面向小情侣、闺蜜和挚友。目标是在用户授权与本地隐私优先的前提下，把微信、QQ、小红书、抖音中同一个人的聊天内容聚合到一个可检索、可标注、可回看的时间线中。

当前仓库包含：

- [`docs/PRD.md`](docs/PRD.md)：产品需求文档、MVP 范围、路线图、风险与验证计划。

## 核心问题

亲密关系中的沟通分散在多个平台：事情在微信说、链接在小红书发、视频在抖音聊、文件在 QQ 传。用户需要 remembering who said what、when、where，并且希望把零散信息沉淀成标签和共同记忆。

## 产品原则

1. **隐私优先**：数据默认只保存在用户设备，明确授权后才导入，不做云端集中式抓取。
2. **用户可控**：同一个人由用户手动确认，导入内容可删除、可重新同步。
3. **渐进可行**：先做可靠的手动/半自动导入、统一搜索和标签，再探索实时同步与内容内嵌。
4. **平台合规**：避免违反第三方平台条款，优先使用用户主动导出的数据、系统分享能力或官方能力。
5. **三端适配**：iPhone、iPad、Mac 使用 SwiftUI 适配各自设备形态；iPhone / iPad 优先发布，Mac 架构从第一天预留。
6. **架构可迁移**：Apple 端 MVP 使用 SwiftUI，但产品核心采用 Kotlin Multiplatform，从第一天起避免把领域逻辑、导入解析、搜索和标签规则写成无法迁移的 SwiftUI 单体。

## 技术策略

产品采用“Apple 设备先发布、核心可复用”的路线：

```text
iPhone / iPad SwiftUI 界面
Mac SwiftUI 界面，后续正式接入
Android Jetpack Compose 界面，后续接入
        ↓
Kotlin Multiplatform Shared Core
    ├── 联系人与平台身份模型
    ├── 聊天记录导入解析
    ├── 时间线合并与去重
    ├── 全局搜索查询
    ├── 标签与事实沉淀
    └── 加密备份格式
        ↓
SQLite / FTS 本地索引
```

iPhone、iPad、Mac 与 Android 分别实现各自的平台适配层，包括文件选择、系统分享入口、OCR、生物识别锁、原帖跳转和权限说明。这样 Apple 端 MVP 可以快速推进，Android 正式启动时不需要重写全部产品逻辑。

## Android 版本

- Jetpack Compose + Material 3 自适应界面
- 手机底部导航，平板/横屏/大屏自动切换侧边导航栏
- 时间线 / 标签 / 联系人 / 设置
- 全局文本搜索、平台筛选、人物筛选、收藏
- 食物爱好 / Todo / 约定一起做等消息标签
- 本地 JSON 持久化与导入去重
- ChatLab JSON / JSONL（QQ、小红书等导出格式）
- WeChatDataAnalysis `messages.json` / ZIP / 导出目录
- 抖音数据导出 JSON
- 通用 JSON 数组
- 解密后的微信 `contact.db + message_*.db` 目录
- SAF 单文件导入、目录导入、应用内 Inbox、可持久授权的自动扫描目录

构建时安装 Android Studio 或 Android SDK 后，在 `apps/android` 执行：

```bash
./gradlew :app:assembleDebug
```

产物位于：

```text
apps/android/app/build/outputs/apk/debug/app-debug.apk
```

Release 构建使用：

```bash
./gradlew :app:assembleRelease
```

当前 Android debug 与 release 构建已在本机通过；GitHub Actions 也会构建 debug APK 并上传 artifact。

### WeChatDataAnalysis 集成

ChatMemory 不内置微信进程扫描、数据库密钥提取或 SQLCipher 解密。推荐流程是：

```text
WeChatDataAnalysis 负责用户本机数据的解密 / 导出
        ↓
输出 messages.json / ZIP / folder 增量导出
        ↓
ChatMemory 只解析这些导出产物
        ↓
绑定联系人、合并时间线、搜索、打标签
```

支持的 WeChatDataAnalysis 导出结构：

```text
export/
  xxx/
    meta.json
    messages.json
    media/
```

单聊和群聊消息都会保留 `serverId/localId` 作为去重标识；重复扫描同一导出目录不会重复入库。

## 当前完成度

| 平台 | 状态 | 说明 |
|---|---|---|
| iPhone / iPad | SwiftUI target 已配置 | `TARGETED_DEVICE_FAMILY=1,2`，手机用 TabView，iPad regular width 用三栏 NavigationSplitView |
| macOS | SwiftUI target 已完成 | `ChatMemoryMac`、Inbox、Finder/文件导入、DMG 打包脚本可用 |
| Android | 已通过 debug/release 构建 | 独立 Jetpack Compose 版本，非 Mac Catalyst 套壳 |

本机没有完整 Xcode 时，无法在本机跑 iOS SDK 编译；安装 Xcode 后执行：

```bash
cd Prototype
xcodegen generate
open ChatMemory.xcodeproj
```

选择 `ChatMemoryiOS`，用 iPhone Simulator 或 iPad Simulator 构建。

## 设备适配策略

- **iPhone**：主打单手搜索、快速查看和消息标注，使用紧凑布局与底部主导航。
- **iPad**：利用 Regular 宽度展示双栏或三栏结构，支持 Split View、Stage Manager、外接键盘和触控板。
- **Mac**：使用原生 SwiftUI macOS 目标，提供多窗口、侧边栏导航、菜单栏命令、Finder 文件导入、拖拽导入和快捷键。

开发验证顺序：先用 iPad 真机完成 iOS 能力测试，再用 Xcode iPhone Simulator 验证小屏与单手交互，最后接入 macOS 目标验证桌面工作流。

## 开源与隐私

项目代码以 MIT 协议开源。ChatMemory 只处理用户主动导入、分享或选择的数据；不会读取微信进程内存，不会提取微信数据库密钥，也不会上传用户聊天内容。

更多边界说明见 [docs/OPEN_SOURCE.md](docs/OPEN_SOURCE.md) 和 [docs/REAL_IMPORT.md](docs/REAL_IMPORT.md)。
