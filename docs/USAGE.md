# ChatMemory 使用教程

> 最后更新：2026-10-29  
> 适用版本：main 分支 / Android `0.9.0` / Apple 原型 `0.8.0`

ChatMemory 是一个本地优先的聊天记忆整理器。它不把微信、QQ、小红书、抖音的数据上传到服务器，而是把你主动导出的记录整理成：

- 统一时间线
- 跨平台搜索
- 人物标签
- 食物爱好 / Todo / 约定一起做
- 原帖或原消息跳转
- 可备份的本地 JSON

---

## 1. 先理解 5 个核心概念

### 1.1 联系人 = 真实的人

“联系人”不是某个平台账号，而是你在现实中的同一个人。

例如：

```text
联系人：小鹿
├─ 微信：xiaolu_wx
├─ QQ：123456
├─ 小红书：xiaolu_xhs
└─ 抖音：xiaolu_dy
```

导入前先选中这个人，再导入不同平台的导出文件。这样所有记录会合并到同一条时间线。

### 1.2 时间线

时间线按时间倒序展示消息，并保留平台颜色标识：

- 微信
- QQ
- 小红书
- 抖音

### 1.3 标签

标签用于沉淀“事实”和“约定”，例如：

```text
食物爱好
Todo
约定一起做
旅行灵感
生日礼物
过敏源
```

### 1.4 去重

导入器会根据平台、时间、内容、链接和来源 ID 去重。重复导入同一份文件不会无限追加。

### 1.5 本地优先

聊天记录保存在你设备本地。ChatMemory 不上传数据，不读取微信进程，不提取数据库密钥，不自动解密微信数据库。

---

## 2. 安装

### 2.1 macOS

#### 方式一：从源码打包

```bash
git clone https://github.com/rainnn-w/chat-app-idea.git
cd chat-app-idea/Prototype
./Scripts/package-mac.sh
```

产物在：

```text
Prototype/dist/ChatMemory-0.8.0-macOS.dmg
Prototype/dist/ChatMemory-0.8.0-macOS.zip
```

打开 DMG，把 `ChatMemory.app` 拖到 `Applications`。

这个包使用 ad-hoc 签名，没有 Apple notarization。首次打开如果 macOS 提示无法验证开发者，可以：

1. 在 Finder 中找到 `ChatMemory.app`
2. 右键 → 打开
3. 再点“打开”

不要对来路不明的构建包使用绕过 Gatekeeper 的方法。

#### 方式二：直接运行 Swift Package

```bash
cd Prototype
swift run ChatMemoryPrototypeApp
```

### 2.2 iPhone / iPad

需要 macOS + Xcode：

```bash
brew install xcodegen
cd Prototype
xcodegen generate
open ChatMemory.xcodeproj
```

然后：

1. Xcode 顶部选择 `ChatMemoryiOS`
2. 选择你的 iPhone / iPad 或模拟器
3. 按 `Cmd + R` 运行
4. 如需长期安装到真机，在 Xcode 中登录自己的 Apple ID 并配置 Personal Team

iPhone 使用底部 Tab；iPad regular width 会显示三栏布局。

### 2.3 Android

需要 JDK 17 + Android SDK。

从源码构建：

```bash
cd apps/android
./gradlew :app:assembleDebug
```

产物：

```text
apps/android/app/build/outputs/apk/debug/app-debug.apk
```

安装：

```bash
adb install -r apps/android/app/build/outputs/apk/debug/app-debug.apk
```

也可以把 `app-debug.apk` 发到手机上，用文件管理器安装。系统提示“未知来源”时，允许本次安装即可。

GitHub Actions 每次推送也会生成 Android debug artifact：

1. 打开仓库 Actions 页面
2. 进入最近一次成功的 `CI`
3. 下载 `ChatMemory-android-debug`
4. 解压后安装 APK

Release APK 需要签名后才能直接安装；不建议普通用户直接使用 `app-release-unsigned.apk`。

---

## 3. 第一次启动

### Apple 端

第一次启动会加载示例数据，方便你熟悉界面。

建议先做一次：

```text
设置 → 清空本地数据
```

然后再导入真实数据。

注意：清空不可撤销，清空前最好先“导出 JSON”备份。

### Android 端

第一次启动会有一个“示例联系人”。你可以直接用它测试导入，正式使用时再新建真实联系人。

Android 目前没有单独的“清空数据”按钮。如需完全重置，可以在系统设置里清除应用数据，或卸载后重装。

---

## 4. 创建联系人

### Apple 端

iPhone：

```text
联系人 → 添加
```

iPad / Mac：

```text
左侧联系人栏 → 添加
```

建议这样填：

| 字段 | 示例 |
|---|---|
| 姓名 | 小鹿 |
| 副标题 | 微信 · QQ · 小红书 · 抖音 |

### Android 端

```text
联系人 → 右上角 + → 填写姓名 / 平台身份说明
```

示例：

```text
姓名：小鹿
平台身份说明：微信 · QQ · 小红书 · 抖音
```

> 导入前一定要先选中联系人。当前导入逻辑会把导入文件绑定到当前选中的联系人。

---

## 5. 准备导出数据

ChatMemory 的原则是：

```text
原始平台 / 可信开源工具负责导出
ChatMemory 负责整理、搜索、标签、时间线
```

### 5.1 微信：推荐 WeChatDataAnalysis

推荐项目：

<https://github.com/LifeArchiveProject/WeChatDataAnalysis>

请按照该项目自己的 README 完成本机导出。你最终需要拿到下面任意一种：

#### 推荐：单个会话 `messages.json`

```text
export/
  xxx/
    meta.json
    messages.json
    media/
```

`messages.json` 关键字段：

```json
{
  "schemaVersion": 1,
  "account": "wxid_example",
  "conversation": {
    "username": "peer_example",
    "displayName": "示例联系人",
    "isGroup": false
  },
  "messages": [
    {
      "serverId": "server-1001",
      "localId": 1,
      "createTime": 1792173600,
      "renderType": "text",
      "isSent": false,
      "senderUsername": "peer_example",
      "senderDisplayName": "示例联系人",
      "content": "不要香菜"
    }
  ]
}
```

#### 支持：包含 `messages.json` 的导出目录

```text
export-root/
  conversation-a/
    meta.json
    messages.json
  conversation-b/
    meta.json
    messages.json
```

#### 支持：ZIP

Android 支持包含 `messages.json` 的 ZIP。Apple 当前主要导入 `messages.json` 或目录。

#### 重要提醒

不要把很多无关会话一次性导入到同一个联系人。

例如，如果你选中“小鹿”，然后导入一个包含 50 个群聊的导出目录，这 50 个会话都可能被绑定到“小鹿”。

推荐做法：

```text
一次只导出 / 导入一个人的微信会话
```

### 5.2 QQ / 小红书：ChatLab JSON / JSONL

支持结构：

```json
{
  "chatlab": {
    "version": "0.0.2"
  },
  "meta": {
    "name": "示例私聊",
    "platform": "xiaohongshu",
    "type": "private"
  },
  "members": [
    {
      "platformId": "xhs-user-self",
      "accountName": "我"
    }
  ],
  "messages": [
    {
      "platformMessageId": "message-001",
      "sender": "xhs-user-self",
      "accountName": "我",
      "timestamp": 1792173600,
      "content": "明天去市集"
    }
  ]
}
```

也支持 JSONL：

```jsonl
{"_type":"header","meta":{"platform":"xiaohongshu"}}
{"_type":"member","platformId":"self","accountName":"我","isSelf":true}
{"_type":"message","platformMessageId":"m-1","sender":"self","timestamp":1792173600,"content":"明天见"}
```

参考项目：

- 小红书：<https://github.com/kumikosoli/xhs-chatlab-exporter>
- QQ：<https://github.com/weq-devs/WeQ>

### 5.3 抖音：数据导出 JSON

参考项目：

<https://github.com/ZhangYukwiver/DouyinDataReview>

支持结构：

```json
{
  "schemaVersion": 2,
  "chatConversations": [
    {
      "id": "conv-1",
      "kind": "friend",
      "name": "好友"
    }
  ],
  "chatMessages": [
    {
      "id": "message-1",
      "conversationId": "conv-1",
      "conversationName": "好友",
      "senderId": "peer",
      "senderName": "好友",
      "sentAt": "2026-10-14T01:00:00Z",
      "text": "这个视频很好笑"
    }
  ]
}
```

### 5.4 解密后的微信 SQLite 目录

如果你已经有可信工具生成的明文库，可以导入这种结构：

```text
decrypted/
  contact/
    contact.db
  message/
    message_0.db
    message_1.db
  session/
    session.db
```

ChatMemory 只读取已经解密后的 SQLite 文件。

它不会：

- 读取微信进程
- 提取数据库密钥
- 解密 SQLCipher / WCDB
- 自动绕过系统权限

---

## 6. Apple 端导入教程

### 6.1 导入 WeChatDataAnalysis 单个 `messages.json`

1. 启动 ChatMemory
2. 在左侧或联系人 Tab 选中目标联系人
3. 进入时间线
4. 点击“录入聊天记忆”
5. 选择“真实文件”
6. 点击“选择记录文件”
7. 选择 `messages.json`
8. 确认识别为：

```text
WeChatDataAnalysis 导出
```

9. 选择标签，可选
10. 点击保存

### 6.2 导入 WeChatDataAnalysis 导出目录

1. 选中目标联系人
2. 打开“录入聊天记忆”
3. 选择“真实文件”
4. 点击“解密后的微信目录”
5. 选择导出根目录

如果目录里有 `messages.json`，ChatMemory 会自动递归查找并导入。

导入完成后会显示：

```text
WeChatDataAnalysis 导入完成：N 条消息 / 跳过 M 条重复
```

### 6.3 导入 ChatLab / 抖音 / 通用 JSON

1. 选中联系人
2. 进入“录入聊天记忆”
3. 点击“选择记录文件”
4. 选择 `.json` / `.jsonl` / `.html` / `.mht`
5. 确认格式识别
6. 保存

支持格式包括：

| 来源 | 格式 |
|---|---|
| 微信 | `messages.json`、解密后 SQLite |
| QQ | ChatLab JSON / JSONL、HTML / MHT |
| 小红书 | ChatLab JSON / JSONL、HTML |
| 抖音 | 数据导出 JSON |
| 通用 | `messages` / `data` / `items` / `records` JSON |

### 6.4 使用 Apple Inbox 自动导入

进入：

```text
设置 → 自动导入 Inbox
```

步骤：

1. 打开“自动导入”
2. 选择“目标联系人”
3. 把导出的 `messages.json` 放进 Inbox
4. 点击“立即检查”

设置页会显示 Inbox 路径。

macOS 默认位置类似：

```text
~/Library/Application Support/ChatMemory/Inbox
```

注意：不要把他人聊天记录未经同意放进 Inbox。

---

## 7. Android 端导入教程

### 7.1 单文件导入

1. 打开 ChatMemory
2. 进入“联系人”
3. 点击要导入的人
4. 进入“设置”
5. 点击“选择导出文件”
6. 选择：
   - `messages.json`
   - ChatLab `.json` / `.jsonl`
   - 抖音导出 `.json`
   - 包含 `messages.json` 的 `.zip`
7. 等待导入完成

成功后返回时间线查看。

### 7.2 目录导入

1. 先选中联系人
2. 进入“设置”
3. 点击“选择解密微信目录”

Android 会扫描目录中的：

```text
*.db
*.json
*.jsonl
*.zip
```

支持：

```text
WeChatDataAnalysis/
  conversation/
    messages.json

decrypted/
  contact/contact.db
  message/message_0.db
```

### 7.3 自动扫描目录

1. 选中联系人
2. 进入“设置”
3. 在“自动扫描”里点击“绑定扫描目录”
4. 选择你的导出目录
5. 之后点击“立即扫描”

应用启动时也会尝试扫描已绑定目录。

当前自动扫描是“启动时扫描 + 手动立即扫描”，不是后台常驻监听。如果你刚让外部工具导出了新文件，回到 App 后点一次“立即扫描”最可靠。

### 7.4 应用 Inbox

Android 应用私有目录里有：

```text
Inbox/
  Processed/
  Failed/
```

普通用户不建议手动操作私有目录。更简单的方式是：

```text
设置 → 选择导出文件 / 选择解密微信目录 / 立即扫描
```

---

## 8. 手动录入一条消息

Apple 端：

1. 选中联系人
2. 打开“录入聊天记忆”
3. 选择“单条”
4. 选择平台
5. 选择发送者：我 / 对方 / 系统
6. 选择时间
7. 填写内容
8. 可选：填写原帖标题、原帖链接
9. 选择标签
10. 保存

Android 端：

1. 时间线右下角点击“补充消息”
2. 选择平台
3. 选择发送者
4. 填写内容
5. 可选：填写链接
6. 保存

适用场景：

- 你只想记住一句重要的话
- 截图里的内容还没写自动 OCR
- 某个平台暂时没有导出格式

---

## 9. 搜索

### Apple 端高级搜索

在时间线搜索框中可以使用：

#### 普通文本

```text
香菜
```

#### 多个关键词 AND

```text
香菜 周五
```

表示同时包含“香菜”和“周五”。

#### 短语

```text
"不要香菜"
```

#### 联系人过滤

```text
person:小鹿 香菜
```

#### 平台过滤

```text
platform:xhs 市集
```

平台别名支持：

| 平台 | 示例 |
|---|---|
| 微信 | `wechat` / `weixin` / `微信` |
| QQ | `qq` |
| 小红书 | `xhs` / `xiaohongshu` / `小红书` |
| 抖音 | `douyin` / `抖音` |

#### 标签过滤

```text
tag:食物爱好
tag:Todo
```

#### 收藏过滤

```text
is:favorite
```

#### 组合示例

```text
person:小鹿 platform:wechat tag:食物爱好 香菜
```

### Android 端搜索

Android 时间线搜索框支持：

- 消息内容
- 标题
- 链接
- 联系人名称

另外可以使用：

- 联系人筛选
- 平台筛选
- 标签页查看标签

Android 目前不完整支持 Apple 端的 `person:` / `tag:` / `platform:` 高级语法。

---

## 10. 标签

内置标签：

```text
食物爱好
Todo
约定一起做
```

### 给消息打标签

Apple 端：

1. 在时间线点击一条消息
2. 在详情面板中选择标签
3. 关闭详情

Android 端：

1. 点击消息卡片
2. 底部弹窗里勾选或取消标签

### 推荐用法

| 场景 | 标签 | 示例消息 |
|---|---|---|
| 她说不喜欢香菜 | 食物爱好 | “我不要香菜” |
| 他不吃花生 | 食物爱好 | “花生过敏” |
| 周五取票 | Todo | “记得周五取票” |
| 一起看展 | 约定一起做 | “周六去看展” |
| 旅行计划 | 旅行灵感 | “明年去京都” |

### 按标签查看

Apple 端：

```text
标签 → 选择标签 → 查看标签结果
```

Android 端：

```text
标签 → 点击标签
```

---

## 11. 收藏重要消息

Apple 端：

1. 点击消息
2. 在详情面板中收藏

Android 端：

点击消息卡片右侧的心形图标。

然后可以用：

```text
is:favorite
```

只看收藏。

---

## 12. 导出 / 备份 / 恢复

### Apple 端

进入：

```text
设置 → 导出 JSON
```

导出的 JSON 包含：

- 联系人
- 消息
- 标签
- 导入状态
- 导入批次

恢复：

```text
设置 → 导入 JSON
```

注意：恢复 JSON 会替换当前数据。操作前先再导出一份当前数据。

### Android 端

Android 当前数据保存在应用私有目录：

```text
/data/data/com.rainnn.chatmemory.android/
```

普通用户不需要手动访问。

当前建议：

1. 保留原始导出文件
2. 不要只依赖 ChatMemory 内部数据库
3. 后续版本可以补 Android JSON 导出/恢复

---

## 13. 常见问题

### 13.1 为什么不能直接导入微信加密数据库？

微信 4.x 本地库通常是 SQLCipher / WCDB 加密格式。ChatMemory 故意不实现：

- 读取微信进程内存
- 提取数据库密钥
- 自动 SQLCipher 解密

请先用你信任、你审查过源码的开源工具完成导出，再让 ChatMemory 导入导出产物。

### 13.2 为什么重复导入没有新增消息？

这是去重功能。

同一来源、同一 `serverId/localId`、或相同时间 / 内容 / 链接的消息会被跳过。

### 13.3 为什么导入目录后所有消息都到了同一个人？

因为导入前选中的联系人就是导入目标。

如果要导入多人聊天，不要把包含多个无关会话的大目录一次性导入。先拆分，或一次处理一个人的导出。

### 13.4 为什么群聊发送者有时候不准确？

不同导出器的群聊字段不同。WeChatDataAnalysis 已带 `senderUsername` / `senderDisplayName`，ChatMemory 会优先使用它们。

如果源文件缺少发送者信息，只能显示为“对方”或“系统”。

### 13.5 图片、语音、视频会导入吗？

文本和消息元数据会导入。

非文本消息会显示占位：

```text
[图片]
[语音]
[视频]
[表情]
[文件]
[位置]
[通话]
```

如果导出 JSON 里有 URL 或本地媒体路径，ChatMemory 会尽量保留标题和链接。完整媒体回放是后续路线图。

### 13.6 能自动同步最新聊天吗？

不能做到无感实时抓取。

当前推荐流程：

```text
外部工具导出最新记录
        ↓
ChatMemory 自动扫描 / 手动导入
        ↓
去重合并
```

Apple Inbox 可以监听放入的新 JSON 文件；Android 可以绑定目录并在启动或手动触发时扫描。

### 13.7 数据会上传吗？

不会。

ChatMemory 没有云端同步服务，没有账号系统，不上传聊天内容、联系人、密钥或导出文件。

### 13.8 可以导入别人的聊天记录吗？

技术上如果文件在你手里就可以解析，但不建议。

请只处理：

- 自己账号的数据
- 已获得对方明确同意的数据
- 法律和平台规则允许你处理的数据

---

## 14. 推荐日常流程

### 单人整理流程

```text
1. 创建联系人“小鹿”
2. 选中“小鹿”
3. 用 WeChatDataAnalysis 导出微信聊天
4. ChatMemory 导入 messages.json
5. 用 ChatLab 导出小红书聊天
6. ChatMemory 导入 chatlab.json
7. 用 DouyinDataReview 导出抖音聊天
8. ChatMemory 导入 JSON
9. 打标签：食物爱好 / Todo / 约定一起做
10. 用搜索回看
```

### 定期更新流程

```text
1. 外部工具增量导出
2. 打开 ChatMemory
3. Android：设置 → 立即扫描
4. Apple：把新 messages.json 放 Inbox，或手动导入
5. 检查新消息并补标签
```

### 约定追踪流程

```text
1. 搜索“周末 / 明天 / 记得 / 一起”
2. 给相关消息打“约定一起做”
3. 需要时按标签查看
4. 完成后可以继续保留记录
```

---

## 15. 隐私与安全清单

使用前建议：

1. 只导出自己有权处理的数据
2. 不把原始导出文件发给他人
3. 不把 `messages.json` 提交到 Git
4. 不把微信数据库、密钥、Cookie、Token 提交到 Git
5. 定期导出 ChatMemory JSON 备份
6. 设备开启文件加密
7. iOS / iPadOS 可依赖系统应用沙盒
8. Android 不要安装来路不明的修改版 APK

推荐加入 `.gitignore` 的内容不要删除：

```text
Research/
Prototype/dist/
apps/android/.gradle/
apps/android/build/
apps/android/app/build/
samples/
*.db
*.sqlite
```

---

## 16. 当前限制

| 能力 | 当前状态 |
|---|---|
| 文本搜索 | 可用 |
| 标签 | 可用 |
| 收藏 | 可用 |
| 时间线合并 | 可用 |
| WeChatDataAnalysis 导入 | 可用 |
| ChatLab 导入 | 可用 |
| 抖音导出导入 | 可用 |
| 解密后微信 SQLite 导入 | 可用 |
| 图片 OCR | 未完成 |
| 内嵌原帖查看 | 未完成，当前主要跳转链接 |
| 完整媒体回放 | 未完成 |
| 发送消息 | 不计划做 |
| 无感实时抓取 | 不做 |
| 云同步 | 不做 |
| Android 后台持续监听 | 未完成 |

---

## 17. 开发者速查

### Apple

```bash
cd Prototype
swift build
swift run DomainSmokeTests
./Scripts/package-mac.sh
```

生成 Xcode 工程：

```bash
cd Prototype
xcodegen generate
open ChatMemory.xcodeproj
```

### Android

```bash
cd apps/android
./gradlew :app:assembleDebug
./gradlew :app:assembleRelease
```

### 文档

| 文档 | 用途 |
|---|---|
| [`docs/PRD.md`](PRD.md) | 产品需求 |
| [`docs/REAL_IMPORT.md`](REAL_IMPORT.md) | 真实数据格式 |
| [`docs/OPEN_SOURCE.md`](OPEN_SOURCE.md) | 开源边界 |
| [`docs/USAGE.md`](USAGE.md) | 本教程 |

