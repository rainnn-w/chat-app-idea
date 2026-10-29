package com.rainnn.chatmemory.android.data

import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.security.MessageDigest

data class WechatContact(
    val username: String,
    val nickname: String,
    val remark: String,
    val alias: String
)

data class WechatRow(
    val rowId: Long,
    val localId: Long,
    val createTime: Long,
    val realSenderId: Long,
    val messageType: Int,
    val content: String
)

class WechatDirectoryImporter {
    fun importDirectory(root: File, personId: String): List<ChatMessage> {
        val contactFile = root.walkTopDown().firstOrNull {
            it.isFile && it.name.equals("contact.db", ignoreCase = true)
        }
        val messageFiles = root.walkTopDown().filter { file ->
            val name = file.name.lowercase()
            file.isFile && name.startsWith("message_") && name.endsWith(".db") &&
                !name.contains("fts") && !name.contains("media") && !name.contains("resource")
        }.sortedBy { it.name }.toList()

        if (messageFiles.isEmpty()) error("没有找到可导入的微信数据库")

        val contacts = contactFile?.let { readContacts(it) }.orEmpty()
        val selfId = contacts.firstOrNull { it.username.startsWith("wxid_") }?.username
        val messages = mutableListOf<ChatMessage>()

        messageFiles.forEach { file ->
            runCatching {
                messages += readMessages(file, contacts, selfId, personId)
            }
        }

        if (messages.isEmpty()) error("微信数据库可打开，但没有读取到消息")
        return messages
    }

    fun importSingleDatabase(file: File, personId: String): List<ChatMessage> {
        val database = SQLiteDatabase.openDatabase(
            file.absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY
        )
        database.use { db ->
            val contacts = runCatching { readContactsWithDatabase(db) }.getOrElse { emptyList() }
            val selfId = contacts.firstOrNull { it.username.startsWith("wxid_") }?.username
            val messages = readMessagesWithDatabase(db, contacts, selfId, personId, file.name)
            if (messages.isEmpty()) error("没有找到 Msg_* 消息表")
            return messages
        }
    }

    private fun readContacts(file: File): List<WechatContact> {
        val database = SQLiteDatabase.openDatabase(
            file.absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY
        )
        return database.use(::readContactsWithDatabase)
    }

    private fun readContactsWithDatabase(database: SQLiteDatabase): List<WechatContact> {
        val results = mutableListOf<WechatContact>()
        database.rawQuery("SELECT * FROM contact", null).use { cursor ->
            while (cursor.moveToNext()) {
                val username = cursor.text("username") ?: continue
                results += WechatContact(
                    username = username,
                    nickname = cursor.text("nick_name").orEmpty(),
                    remark = cursor.text("remark").orEmpty(),
                    alias = cursor.text("alias").orEmpty()
                )
            }
        }
        return results
    }

    private fun readMessages(
        file: File,
        contacts: List<WechatContact>,
        selfId: String?,
        personId: String
    ): List<ChatMessage> {
        val database = SQLiteDatabase.openDatabase(
            file.absolutePath,
            null,
            SQLiteDatabase.OPEN_READONLY
        )
        return database.use {
            readMessagesWithDatabase(it, contacts, selfId, personId, file.name)
        }
    }

    private fun readMessagesWithDatabase(
        database: SQLiteDatabase,
        contacts: List<WechatContact>,
        selfId: String?,
        personId: String,
        databaseName: String
    ): List<ChatMessage> {
        val tableNames = mutableListOf<String>()
        database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Msg_%'",
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                cursor.getString(0)?.let(tableNames::add)
            }
        }
        if (tableNames.isEmpty()) return emptyList()

        val nameById = mutableMapOf<Long, String>()
        runCatching {
            database.rawQuery("SELECT rowid, user_name FROM Name2Id", null).use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.long(0)
                    val username = cursor.text(1)
                    if (id != null && !username.isNullOrEmpty()) nameById[id] = username
                }
            }
        }

        val contactByTable = contacts.associateBy { md5(it.username) }
        val messages = mutableListOf<ChatMessage>()

        tableNames.forEach { table ->
            val safeTable = table.replace("\"", "\"\"")
            runCatching {
                database.rawQuery(
                    "SELECT rowid AS chatmemory_rowid, * FROM \"$safeTable\" ORDER BY create_time ASC",
                    null
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val row = WechatRow(
                            rowId = cursor.long("chatmemory_rowid") ?: 0L,
                            localId = cursor.long("local_id") ?: cursor.long("localid")
                                ?: cursor.long("chatmemory_rowid") ?: 0L,
                            createTime = cursor.long("create_time") ?: cursor.long("createtime") ?: 0L,
                            realSenderId = cursor.long("real_sender_id") ?: cursor.long("real_sender") ?: -1L,
                            messageType = cursor.int("local_type") ?: cursor.int("type") ?: 0,
                            content = cursor.text("message_content")
                                ?: cursor.text("content")
                                ?: cursor.text("strcontent")
                                ?: ""
                        )
                        val senderWxid = nameById[row.realSenderId].orEmpty()
                        val tableHash = table.removePrefix("Msg_")
                        val contact = contactByTable[tableHash]
                        val title = contact?.remark ?: contact?.nickname
                            ?: contact?.alias ?: "微信消息"
                        val text = cleanMessage(row.content, row.messageType)
                            .ifBlank { placeholder(row.messageType) }

                        messages += ChatMessage(
                            personId = personId,
                            platform = ChatPlatform.WECHAT,
                            sender = if (senderWxid == selfId) MessageSender.ME else MessageSender.PEER,
                            sentAtMillis = normalizeTime(row.createTime),
                            text = text,
                            externalTitle = title,
                            externalUrl = xmlValue("url", row.content),
                                sourceIdentifier = "wechat-decrypt:$databaseName:$table:${row.localId}"
                        )
                    }
                }
            }
        }

        return messages
    }

    private fun md5(value: String): String =
        MessageDigest.getInstance("MD5").digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    private fun normalizeTime(seconds: Long): Long =
        if (seconds > 10_000_000_000L) seconds else seconds * 1000L

    private fun cleanMessage(value: String, messageType: Int): String {
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

    private fun placeholder(type: Int): String = when (type) {
        3 -> "[图片]"
        34 -> "[语音]"
        43 -> "[视频]"
        47 -> "[表情]"
        48 -> "[位置]"
        49 -> "[链接 / 文件 / 小程序]"
        50 -> "[通话]"
        else -> "[消息]"
    }

    private fun xmlValue(name: String, text: String): String? {
        val match = Regex("<$name[^>]*>(.*?)</$name>", RegexOption.DOT_MATCHES_ALL).find(text)
        return match?.groupValues?.get(1)
            ?.replace(Regex("<[^>]+>"), "")
            ?.replace("&amp;", "&")
            ?.replace("&lt;", "<")
            ?.replace("&gt;", ">")
            ?.replace("&quot;", "\"")
            ?.trim()?.ifEmpty { null }
    }

    private fun android.database.Cursor.text(columnName: String): String? {
        val index = getColumnIndex(columnName)
        if (index < 0 || isNull(index)) return null
        return getString(index)
    }

    private fun android.database.Cursor.text(index: Int): String? {
        if (index < 0 || isNull(index)) return null
        return getString(index)
    }

    private fun android.database.Cursor.long(columnName: String): Long? {
        val index = getColumnIndex(columnName)
        return if (index < 0 || isNull(index)) null else getLong(index)
    }

    private fun android.database.Cursor.long(index: Int): Long? {
        return if (index < 0 || isNull(index)) null else getLong(index)
    }

    private fun android.database.Cursor.int(columnName: String): Int? {
        val index = getColumnIndex(columnName)
        return if (index < 0 || isNull(index)) null else getInt(index)
    }
}
