package com.rainnn.chatmemory.android.data

import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

data class ParsedArchive(
    val platform: ChatPlatform,
    val messages: List<ParsedMessage>
)

data class ParsedMessage(
    val sourceIdentifier: String,
    val sender: MessageSender,
    val timestampMillis: Long,
    val text: String,
    val title: String? = null,
    val url: String? = null
)

object AutoChatParsers {
    fun parse(text: String, fileName: String): ParsedArchive {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) error("文件为空")

        if (fileName.endsWith(".jsonl", ignoreCase = true) || trimmed.lines().any { it.trimStart().startsWith("{\"_type\"") }) {
            return parseJsonL(trimmed, fileName)
        }

        return if (trimmed.startsWith("[")) {
            parseGenericArray(JSONArray(trimmed), fileName)
        } else {
            parseObject(JSONObject(trimmed), fileName)
        }
    }

    private fun parseJsonL(text: String, fileName: String): ParsedArchive {
        var platform = ChatPlatform.QQ
        val members = mutableMapOf<String, Boolean>()
        val messages = mutableListOf<ParsedMessage>()

        text.lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { line ->
                val item = runCatching { JSONObject(line) }.getOrNull() ?: return@forEach
                when (item.optString("_type")) {
                    "header" -> platform = detectPlatform(
                        item.optJSONObject("meta")?.optString("platform")
                            ?: item.optString("platform")
                    )
                    "member" -> {
                        val id = item.optString("platformId", item.optString("id"))
                        val self = item.optBoolean("isSelf") ||
                            item.optBoolean("isMe") ||
                            item.optString("accountName") == "我"
                        if (id.isNotEmpty()) members[id] = self
                    }
                    "message" -> {
                        platform = detectPlatform(
                            item.optString("platform", item.optString("platformName", platform.name))
                        )
                        parseMessage(item, fileName, platform, members)?.let(messages::add)
                    }
                }
            }

        if (messages.isEmpty()) error("JSONL 中没有有效消息")
        return ParsedArchive(platform, messages)
    }

    private fun parseObject(root: JSONObject, fileName: String): ParsedArchive {
        root.optJSONArray("chatMessages")?.let { return parseDouyin(root, it, fileName) }

        val messages = root.optJSONArray("messages")
            ?: root.optJSONArray("chatMessages")
            ?: error("JSON 中没有 messages 数组")

        val platform = detectPlatform(
            root.optJSONObject("meta")?.optString("platform")
                ?: root.optString("platform")
        )
        val members = mutableMapOf<String, Boolean>()
        root.optJSONArray("members")?.forEachObject { member ->
            val id = member.optString("platformId", member.optString("id"))
            val self = member.optBoolean("isSelf") ||
                member.optBoolean("isMe") ||
                member.optString("accountName") == "我"
            if (id.isNotEmpty()) members[id] = self
        }

        val parsed = messages.mapObjects { item ->
            parseMessage(item, fileName, platform, members)
        }
        if (parsed.isEmpty()) error("JSON 中没有有效消息")
        return ParsedArchive(platform, parsed)
    }

    private fun parseDouyin(root: JSONObject, messages: JSONArray, fileName: String): ParsedArchive {
        val conversations = mutableMapOf<String, String>()
        root.optJSONArray("chatConversations")?.forEachObject { conversation ->
            val id = conversation.optString("id")
            if (id.isNotEmpty()) conversations[id] = conversation.optString("name")
        }

        val parsed = messages.mapObjects { item ->
            val text = item.optString("text", item.optString("content"))
            val conversationId = item.optString("conversationId")
            parseMessage(item, fileName, ChatPlatform.DOUYIN, emptyMap())?.copy(
                title = item.optString("conversationName", conversations[conversationId].orEmpty()).ifEmpty { null }
            )?.copy(text = text)
        }
        if (parsed.isEmpty()) error("抖音导出中没有有效消息")
        return ParsedArchive(ChatPlatform.DOUYIN, parsed)
    }

    private fun parseGenericArray(array: JSONArray, fileName: String): ParsedArchive {
        val parsed = array.mapObjects { item ->
            val platform = detectPlatform(item.optString("platform"))
            parseMessage(item, fileName, platform, emptyMap())
        }
        if (parsed.isEmpty()) error("JSON 数组中没有有效消息")
        return ParsedArchive(
            detectPlatform(array.optJSONObject(0)?.optString("platform").orEmpty()),
            parsed
        )
    }

    private fun parseMessage(
        item: JSONObject,
        fileName: String,
        fallbackPlatform: ChatPlatform,
        members: Map<String, Boolean>
    ): ParsedMessage? {
        val platform = detectPlatform(item.optString("platform", fallbackPlatform.name))
        val id = item.optString("platformMessageId", item.optString("id", item.optString("server_id")))
        val timestamp = readTimestamp(item)
        if (timestamp <= 0L) return null

        val senderId = item.optString("sender", item.optString("senderId", item.optString("real_sender_id")))
        val accountName = item.optString("accountName", item.optString("senderName"))
        val isSelf = item.optBoolean("isSelf") ||
            item.optBoolean("isMe") ||
            members[senderId] == true ||
            accountName == "我"

        val content = firstNonEmpty(item, "content", "text", "contentText", "message_content")
        val title = firstNonEmpty(item, "title", "externalTitle")
        val safeContent = content.orEmpty()
        val url = firstNonEmpty(item, "url", "externalUrl", "link")
            ?: Regex("https?://[^\\s]+").find(safeContent)?.value

        return ParsedMessage(
            sourceIdentifier = "$platform:$fileName:$id",
            sender = when {
                isSelf -> MessageSender.ME
                accountName == "系统" || platform == ChatPlatform.WECHAT && id.isEmpty() -> MessageSender.SYSTEM
                else -> MessageSender.PEER
            },
            timestampMillis = timestamp,
            text = cleanRichText(safeContent),
            title = title?.takeIf { it.isNotBlank() },
            url = url?.takeIf { it.isNotBlank() }
        )
    }

    private fun readTimestamp(item: JSONObject): Long {
        firstNonEmpty(item, "sentAt", "sentAtISO")?.let { value ->
            runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }
                .getOrElse { runCatching { InstantUtil.parseFallback(value) }.getOrElse { 0L } }
                .let { if (it != 0L) return it }
        }

        val rawSeconds = item.optLong("timestamp", Long.MIN_VALUE)
        if (rawSeconds != Long.MIN_VALUE) {
            return if (rawSeconds > 10_000_000_000L) rawSeconds else rawSeconds * 1000L
        }

        val rawMillis = item.optLong("timestampMillis", Long.MIN_VALUE)
        if (rawMillis != Long.MIN_VALUE) return rawMillis

        val createSeconds = item.optLong("create_time", Long.MIN_VALUE)
        if (createSeconds != Long.MIN_VALUE) {
            return if (createSeconds > 10_000_000_000L) createSeconds else createSeconds * 1000L
        }

        return 0L
    }

    private fun detectPlatform(value: String): ChatPlatform = when (value.trim().lowercase()) {
        "wechat", "weixin", "微信" -> ChatPlatform.WECHAT
        "qq" -> ChatPlatform.QQ
        "xiaohongshu", "xhs", "小红书" -> ChatPlatform.XIAOHONGSHU
        "douyin", "tiktok", "抖音" -> ChatPlatform.DOUYIN
        else -> ChatPlatform.QQ
    }

    private fun firstNonEmpty(item: JSONObject, vararg keys: String): String? {
        keys.forEach { key ->
            val value = item.optString(key, "")
            if (value.isNotBlank()) return value
        }
        return null
    }

    private fun cleanRichText(value: String): String {
        var text = value.trim()
        if (text.startsWith("<msg>") || text.contains("<appmsg>")) {
            val title = xmlValue("title", text)
            val url = xmlValue("url", text)
            text = listOfNotNull(title, url).joinToString("\n")
        }
        return text
            .replace(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("<[^>]+>"), "")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .trim()
    }

    private fun xmlValue(name: String, text: String): String? {
        val match = Regex("<$name[^>]*>(.*?)</$name>", RegexOption.DOT_MATCHES_ALL)
            .find(text) ?: return null
        return match.groupValues[1]
            .replace(Regex("<[^>]+>"), "")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .trim()
            .ifEmpty { null }
    }

    private inline fun JSONArray.forEachObject(action: (JSONObject) -> Unit) {
        for (index in 0 until length()) {
            optJSONObject(index)?.let(action)
        }
    }

    private inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T?): List<T> {
        val result = mutableListOf<T>()
        for (index in 0 until length()) {
            optJSONObject(index)?.let { item -> transform(item)?.let(result::add) }
        }
        return result
    }
}

private object InstantUtil {
    private val fallbacks = listOf(
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
        DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss")
    )

    fun parseFallback(value: String): Long {
        fallbacks.forEach { formatter ->
            runCatching {
                return java.time.LocalDateTime.parse(value, formatter)
                    .atZone(java.time.ZoneId.systemDefault())
                    .toInstant().toEpochMilli()
            }
        }
        return 0L
    }
}
