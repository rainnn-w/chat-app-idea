# 真实来源导入说明

## 微信

### 现状

微信 4.x 的本地消息库（例如 `message_0.db`、`message_1.db`）通常使用 WCDB / SQLCipher 加密。ChatMemory 不会读取、推导或保存微信本地密钥，因此不能直接导入这些加密库。

### 可行路径

1. 使用你信任的开源工具在本机处理你自己账号的数据。
2. 把结果交给 ChatMemory：

   - Mac：选择 `chat.json` / `*.jsonl` / 解密后的微信目录。
   - Android：使用系统文件选择器选择 JSON/JSONL，或选择解密后的微信目录；绑定一次目录后可以“立即扫描”。
   - iOS / iPadOS：使用 `fileImporter` 选择导出文件。

当前支持的字段包括：

```json
{
  "time": "2026-10-28 10:00:00",
  "timestamp": 1792173600,
  "sender": "小鹿",
  "type": 1,
  "type_name": "文本",
  "content": "不要香菜",
  "server_id": "server-1001",
  "db": "message_0.db"
}
```

## 参考开源项目

| 项目 | 说明 |
|---|---|
| [ydotdog/wechat-export-macos](https://github.com/ydotdog/wechat-export-macos) | macOS 微信 4.x 解密/导出工具，可导出 TXT/CSV/JSON |
| [Ormicron/chatViewTool](https://github.com/Ormicron/chatViewTool) | Java 图形化微信聊天记录查看工具 |
| [LC044/WeChatMsg](https://github.com/LC044/WeChatMsg) | 早期“留痕”项目，目前主仓库已停止维护 |

## ChatMemory 支持的解密目录结构

```text
decrypted/
  contact/contact.db
  message/message_0.db
  message/message_1.db
  session/session.db
```

ChatMemory 会读取：

```text
contact 表：username / nick_name / remark / alias
Name2Id 表：rowid / user_name
Msg_<md5(username)> 表：local_id / server_id / local_type / create_time / real_sender_id / message_content
```

选择目录时，请选择 `decrypted/` 这一层，而不是单独选择某一个 `.db`。

## 其他平台导出

| 来源 | 推荐参考 | ChatMemory 输入 |
|---|---|---|
| 微信 | [LifeArchiveProject/WeChatDataAnalysis](https://github.com/LifeArchiveProject/WeChatDataAnalysis) | 解密后的 `contact/contact.db + message/message_*.db`，或 `messages.json` / ZIP / folder 导出 |
| QQ | [weq-devs/WeQ](https://github.com/weq-devs/WeQ) | ChatLab JSON / JSONL，或通用 JSON |
| 小红书 | [kumikosoli/xhs-chatlab-exporter](https://github.com/kumikosoli/xhs-chatlab-exporter) | ChatLab JSON / JSONL |
| 抖音 | [ZhangYukwiver/DouyinDataReview](https://github.com/ZhangYukwiver/DouyinDataReview) | `chatConversations` + `chatMessages` 的导出 JSON |

ChatMemory 导入时会按 `platformMessageId/server_id` 和签名去重，不会因为重复扫描而无限追加。

## WeChatDataAnalysis Connector

ChatMemory 支持解析 WeChatDataAnalysis 聊天导出中的 `messages.json`：

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

导入规则：

| WeChatDataAnalysis 字段 | ChatMemory 字段 |
|---|---|
| `conversation.username` | 去重命名空间 |
| `conversation.displayName` | 原帖 / 会话标题兜底 |
| `isSent` | 发送方向 |
| `senderUsername` / `senderDisplayName` | 发送者信息 |
| `createTime` | 统一时间线 |
| `renderType` | 图片 / 语音 / 视频 / 链接等占位 |
| `content` / `title` / `url` | 全文搜索与原帖跳转 |
| `serverId` 或 `localId` | 稳定去重标识 |

在 Apple 端选择 WeChatDataAnalysis 的导出根目录时，ChatMemory 会递归查找所有 `messages.json`。Android 端可选择单个 `messages.json`、包含该文件的 ZIP，或包含这些文件的目录。

ChatMemory 不调用 WeChatDataAnalysis 的密钥获取、进程扫描或数据库解密接口。

> 注意：涉及微信本地密钥、进程内存或绕过签名的方案请自行评估安全、隐私和服务条款风险。ChatMemory 只导入你已经在本机生成/授权的导出结果。

## 隐私要求

- 只导入自己账号的数据。
- 不要导入未获得对方同意的私人聊天。
- 导出文件里如包含手机号、地址、身份证号，请先脱敏。
- `samples/` 目录不要提交到 Git。
