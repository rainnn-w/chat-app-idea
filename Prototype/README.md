# 聊天记忆库 SwiftUI 原型

这个目录先交付一版高优先级 UI 原型：

- iPhone：底部标签导航 + 单列时间线 + 详情 Sheet
- iPad / Mac：三栏 `NavigationSplitView`
- Mac：`Command + N` 快速录入聊天记忆
- 统一视觉语言：渐变主视觉、玻璃卡片、平台颜色、圆角标签、流畅 spring 动画
- 领域逻辑：联系人、消息、平台筛选、全文搜索、标签、日期分组、收藏
 - 0.2.0：本地 JSON 持久化、联系人创建、单条/多行录入、消息编辑与删除、JSON 导入导出、本地数据清空与示例恢复
 - 0.3.0：全局搜索、联系人 / 平台 / 标签 / 收藏查询语法、搜索范围切换、跨联系人结果标识
 - 0.4.0：真实来源导入管线，支持微信 SQLite、QQ HTML/MHT、小红书/抖音导出数据、来源去重和导入批次记录
 - 0.5.0：自动扫描常见微信目录，候选数据库列表、手动指定微信目录、选中后自动解析
 - 0.6.0：适配开源微信导出 JSON（`chat.json`），支持 timestamp、sender、content、server_id 等字段
 - 0.7.0：Inbox 自动监听导入，成功文件归档、失败文件隔离、目标联系人设置和 macOS Finder 快捷打开

自动扫描只会在你点击按钮后运行，只列出候选 `.db` 文件；不会自动导入、上传或读取消息内容。选中某个候选后才会解析。

## 目录

```text
Sources/ChatMemoryDomain       可测试的领域模型，未来迁移到 KMP
Sources/ChatMemoryUI           SwiftUI 界面与设计系统
Sources/ChatMemoryPrototypeApp macOS 可执行原型入口
Sources/DomainSmokeTests       无 XCTest 依赖的逻辑冒烟测试
Tests/ChatMemoryUITests        Xcode 环境下的单元测试
```

## 运行

```bash
cd Prototype
swift run DomainSmokeTests
swift build --product ChatMemoryDomain
```

当前机器只安装了 Command Line Tools，未安装完整 Xcode，因此：

- `swift build --product ChatMemoryDomain` 可以验证领域模块。
- `swift run DomainSmokeTests` 可以验证核心逻辑。
- SwiftUI UI 需要在安装完整 Xcode 后做类型检查和真机 / 模拟器预览。
- `swift test` 依赖 XCTest，同样需要完整 Xcode 工具链。

安装完整 Xcode 后，可以运行 macOS 原型：

```bash
swift run ChatMemoryPrototypeApp
```

如果要生成 iPhone / iPad / Mac 的正式 App 工程，先安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，再执行：

```bash
cd Prototype
xcodegen generate
open ChatMemory.xcodeproj
```

## 打包 Mac 试用版

当前仓库可以在不安装完整 Xcode 的情况下，把 SwiftUI 原型打包成 `.app`、`.zip` 和 `.dmg`：

```bash
cd Prototype
./Scripts/package-mac.sh
```

产物位于：

```text
Prototype/dist/ChatMemory-0.7.0-macOS.zip
Prototype/dist/ChatMemory-0.7.0-macOS.dmg
```

这个包使用 ad-hoc 签名，未做 Apple Notarization。朋友首次打开时，如果 macOS 提示无法验证开发者，需要右键选择“打开”，或在“系统设置 > 隐私与安全性”里点击“仍要打开”。

