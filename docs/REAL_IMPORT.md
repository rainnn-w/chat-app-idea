# 真实来源导入说明

## 微信

### 现状

微信 4.x 的本地消息库（例如 `message_0.db`、`message_1.db`）通常使用 WCDB / SQLCipher 加密。ChatMemory 不会读取、推导或保存微信本地密钥，因此不能直接导入这些加密库。

### 可行路径

1. 使用你信任的开源工具在本机处理你自己账号的数据，并导出为结构化 `chat.json`。
2. 在 ChatMemory 中选择：

```text
录入 > 真实记录文件 > chat.json
```

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

> 注意：涉及微信本地密钥、进程内存或绕过签名的方案请自行评估安全、隐私和服务条款风险。ChatMemory 只导入你已经在本机生成/授权的导出结果。

## 隐私要求

- 只导入自己账号的数据。
- 不要导入未获得对方同意的私人聊天。
- 导出文件里如包含手机号、地址、身份证号，请先脱敏。
- `samples/` 目录不要提交到 Git。
