package com.rainnn.chatmemory.android.data

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

class ChatRepository(
    private val context: Context,
    seed: Boolean = true
) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences("chat_memory_settings", Context.MODE_PRIVATE)

    private val storeDirectory = File(context.filesDir, "data").apply { mkdirs() }
    private val storeFile = File(storeDirectory, "store.json")
    val inboxDirectory = File(context.filesDir, "Inbox").apply { mkdirs() }
    val processedDirectory = File(inboxDirectory, "Processed").apply { mkdirs() }
    val failedDirectory = File(inboxDirectory, "Failed").apply { mkdirs() }

    var state by mutableStateOf(load(seed))
        private set

    init {
        state = state.copy(
            watchedDirectoryUri = preferences.getString(KEY_WATCHED_DIRECTORY, null)
        )
    }

    fun select(personId: String?) {
        state = state.copy(selectedPersonId = personId, selectedMessageId = null)
    }

    fun setSearchText(value: String) {
        state = state.copy(searchText = value)
    }

    fun togglePlatform(platform: ChatPlatform) {
        val current = state.selectedPlatforms
        val next = when {
            platform in current && current.size == 1 -> ChatPlatform.entries.toSet()
            platform in current -> current - platform
            else -> current + platform
        }
        state = state.copy(selectedPlatforms = next)
    }

    fun selectTag(tagId: String?) {
        state = state.copy(selectedTagId = tagId)
    }

    fun selectMessage(messageId: String?) {
        state = state.copy(selectedMessageId = messageId)
    }

    fun clearNotice() {
        state = state.copy(importSummary = null, errorMessage = null)
    }

    fun toggleFavorite(message: ChatMessage) {
        updateMessages(state.messages.map {
            if (it.id == message.id) it.copy(isFavorite = !it.isFavorite) else it
        })
    }

    fun toggleTag(tag: ChatTag, message: ChatMessage) {
        updateMessages(state.messages.map {
            if (it.id != message.id) {
                it
            } else if (tag.id in it.tagIds) {
                it.copy(tagIds = it.tagIds - tag.id)
            } else {
                it.copy(tagIds = it.tagIds + tag.id)
            }
        })
    }

    fun addPerson(name: String, subtitle: String): ChatPerson? {
        val trimmedName = name.trim()
        if (trimmedName.isEmpty()) return null

        val person = ChatPerson(
            name = trimmedName,
            subtitle = subtitle.trim().ifEmpty { "新联系人" }
        )
        state = state.copy(
            people = state.people + person,
            selectedPersonId = person.id
        )
        save()
        return person
    }

    fun addMessage(
        personId: String = state.selectedPersonId.orEmpty(),
        platform: ChatPlatform,
        sender: MessageSender,
        sentAtMillis: Long = System.currentTimeMillis(),
        text: String,
        externalTitle: String? = null,
        externalUrl: String? = null,
        tagIds: Set<String> = emptySet()
    ) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || state.people.none { it.id == personId }) return

        val message = ChatMessage(
            personId = personId,
            platform = platform,
            sender = sender,
            sentAtMillis = sentAtMillis,
            text = trimmed,
            externalTitle = externalTitle?.trim()?.ifEmpty { null },
            externalUrl = externalUrl?.trim()?.ifEmpty { null },
            tagIds = tagIds
        )
        updateMessages(state.messages + message)
    }

    suspend fun importUri(uri: Uri, displayName: String?, personId: String?): ImportOutcome =
        withContext(Dispatchers.IO) {
            val target = personId ?: state.selectedPersonId
            if (target == null || state.people.none { it.id == target }) {
                return@withContext ImportOutcome(false, "请先在联系人页选择要绑定的人")
            }

            val name = displayName ?: queryDisplayName(uri) ?: "import.json"
            runCatching {
                when {
                    name.endsWith(".db", ignoreCase = true) -> {
                        val temp = copyUriToCache(uri, name)
                        try {
                            val messages = WechatDirectoryImporter().importSingleDatabase(temp, target)
                            mergeMessages(messages)
                        } finally {
                            temp.delete()
                        }
                    }
                    name.endsWith(".zip", ignoreCase = true) -> {
                        val bytes = context.contentResolver.openInputStream(uri)
                            ?.use { it.readBytes() }
                            ?: error("无法读取所选 ZIP")
                        val parsed = AutoChatParsers.parseZip(bytes, name)
                        importParsed(parsed, target)
                    }
                    else -> {
                        val text = context.contentResolver.openInputStream(uri)
                            ?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                            ?: error("无法读取所选文件")
                        val parsed = AutoChatParsers.parse(text, name)
                        importParsed(parsed, target)
                    }
                }
            }.fold(
                onSuccess = { count ->
                    val text = "导入 $name · $count 条消息"
                    state = state.copy(importSummary = text, errorMessage = null)
                    ImportOutcome(true, text)
                },
                onFailure = { error ->
                    val text = error.message ?: "导入失败：文件格式无法识别"
                    state = state.copy(errorMessage = text)
                    ImportOutcome(false, text)
                }
            )
        }

    suspend fun importDirectoryUri(uri: Uri, personId: String?): ImportOutcome =
        withContext(Dispatchers.IO) {
            val target = personId ?: state.selectedPersonId
            if (target == null || state.people.none { it.id == target }) {
                return@withContext ImportOutcome(false, "请先选择要绑定的联系人")
            }

            val root = DocumentFile.fromTreeUri(context, uri)
            if (root == null || !root.isDirectory) {
                return@withContext ImportOutcome(false, "所选目录无法访问")
            }

            val temporary = File(context.cacheDir, "import-${UUID.randomUUID()}").apply { mkdirs() }
            try {
                copySupportedFiles(root, temporary)
                var total = 0
                val warnings = mutableListOf<String>()

                runCatching {
                    total += mergeMessages(WechatDirectoryImporter().importDirectory(temporary, target))
                }.onFailure { if (it.message != "没有找到可导入的微信数据库") warnings += it.message.orEmpty() }

                temporary.walkTopDown()
                    .filter { it.isFile && it.extension.lowercase() in listOf("json", "jsonl", "zip") }
                    .forEach { file ->
                        runCatching {
                            val parsed = when (file.extension.lowercase()) {
                                "zip" -> AutoChatParsers.parseZip(file.readBytes(), file.name)
                                else -> AutoChatParsers.parse(file.readText(), file.name)
                            }
                            total += importParsed(parsed, target)
                        }.onFailure { warnings += "${file.name}: ${it.message.orEmpty()}" }
                    }

                if (total == 0) {
                    val reason = warnings.joinToString("；").ifEmpty { "目录中没有支持的聊天文件" }
                    state = state.copy(errorMessage = reason)
                    ImportOutcome(false, reason)
                } else {
                    val summary = "目录导入完成 · $total 条消息"
                    state = state.copy(importSummary = summary, errorMessage = warnings.firstOrNull())
                    ImportOutcome(true, summary)
                }
            } finally {
                temporary.deleteRecursively()
            }
        }

    suspend fun importInbox(personId: String?): ImportOutcome = withContext(Dispatchers.IO) {
        val target = personId ?: state.selectedPersonId
        if (target == null || state.people.none { it.id == target }) {
            return@withContext ImportOutcome(false, "请先选择要绑定的联系人")
        }

        val files = inboxDirectory.listFiles { file -> file.isFile } ?: emptyArray()
        var imported = 0
        val errors = mutableListOf<String>()

        files.forEach { file ->
            runCatching {
                val count = when (file.extension.lowercase()) {
                    "json", "jsonl" -> importParsed(
                        AutoChatParsers.parse(file.readText(), file.name),
                        target
                    )
                    "db" -> mergeMessages(WechatDirectoryImporter().importSingleDatabase(file, target))
                    "zip" -> importParsed(
                        AutoChatParsers.parseZip(file.readBytes(), file.name),
                        target
                    )
                    else -> error("暂不支持该扩展名")
                }
                imported += count
                file.renameTo(File(processedDirectory, uniqueFileName(file.name)))
            }.onFailure {
                errors += "${file.name}: ${it.message.orEmpty()}"
                file.renameTo(File(failedDirectory, uniqueFileName(file.name)))
            }
        }

        if (imported == 0) {
            val text = errors.joinToString("；").ifEmpty { "Inbox 中没有待导入文件" }
            state = state.copy(errorMessage = text)
            ImportOutcome(false, text)
        } else {
            val text = "Inbox 导入完成 · $imported 条消息"
            state = state.copy(importSummary = text, errorMessage = errors.firstOrNull())
            ImportOutcome(true, text)
        }
    }

    fun setWatchedDirectory(uri: Uri) {
        preferences.edit().putString(KEY_WATCHED_DIRECTORY, uri.toString()).apply()
        state = state.copy(
            watchedDirectoryUri = uri.toString(),
            automationStatus = "已绑定自动扫描目录，启动 App 后可一键刷新"
        )
    }

    suspend fun refreshWatchedDirectory(personId: String?): ImportOutcome =
        withContext(Dispatchers.IO) {
            val value = state.watchedDirectoryUri
            if (value.isNullOrBlank()) {
                ImportOutcome(false, "尚未选择自动扫描目录")
            } else {
                val result = importDirectoryUri(Uri.parse(value), personId)
                state = state.copy(automationStatus = result.message)
                result
            }
        }

    private fun importParsed(parsed: ParsedArchive, targetPersonId: String): Int {
        if (state.people.none { it.id == targetPersonId }) return 0

        val messages = parsed.messages.mapNotNull { raw ->
            val time = raw.timestampMillis
            if (time <= 0L) return@mapNotNull null

            ChatMessage(
                personId = targetPersonId,
                platform = parsed.platform,
                sender = raw.sender,
                sentAtMillis = time,
                text = raw.text.ifBlank { "[ unsupported content ]" },
                externalTitle = raw.title,
                externalUrl = raw.url,
                sourceIdentifier = raw.sourceIdentifier
            )
        }
        return mergeMessages(messages)
    }

    private fun mergeMessages(incoming: List<ChatMessage>): Int {
        val existingSignatures = state.messages.map { it.dedupSignature }.toMutableSet()
        val existingSources = state.messages.mapNotNull { it.sourceIdentifier }.toMutableSet()
        var added = 0
        val merged = state.messages.toMutableList()

        incoming.forEach { message ->
            val repeatedSource = message.sourceIdentifier != null &&
                message.sourceIdentifier in existingSources
            if (!repeatedSource && message.dedupSignature !in existingSignatures) {
                merged += message
                existingSignatures += message.dedupSignature
                message.sourceIdentifier?.let(existingSources::add)
                added += 1
            }
        }

        if (added > 0) updateMessages(merged)
        return added
    }

    private fun updateMessages(messages: List<ChatMessage>) {
        state = state.copy(messages = messages.sortedByDescending { it.sentAtMillis })
        save()
    }

    private fun load(withSeed: Boolean): ChatState {
        if (!storeFile.exists()) {
            return if (withSeed) defaultState() else ChatState()
        }

        return runCatching {
            val root = JSONObject(storeFile.readText())
            val people = root.optJSONArray("people")?.mapObject { index ->
                val item = getJSONObject(index)
                ChatPerson(
                    id = item.optString("id", UUID.randomUUID().toString()),
                    name = item.optString("name"),
                    subtitle = item.optString("subtitle")
                )
            }.orEmpty()

            val tags = root.optJSONArray("tags")?.mapObject { index ->
                val item = getJSONObject(index)
                ChatTag(
                    id = item.optString("id"),
                    name = item.optString("name"),
                    symbolName = item.optString("symbolName", "sell")
                )
            }.orEmpty()

            val messages = root.optJSONArray("messages")?.mapObject { index ->
                val item = getJSONObject(index)
                ChatMessage(
                    id = item.optString("id", UUID.randomUUID().toString()),
                    personId = item.optString("personId"),
                    platform = enumValueOf(item.optString("platform", "WECHAT")),
                    sender = enumValueOf(item.optString("sender", "PEER")),
                    sentAtMillis = item.optLong("sentAtMillis"),
                    text = item.optString("text"),
                    externalTitle = item.optString("externalTitle").ifEmpty { null },
                    externalUrl = item.optString("externalUrl").ifEmpty { null },
                    tagIds = item.optJSONArray("tagIds")?.mapIndex { getString(it) }?.toSet()
                        ?: emptySet(),
                    isFavorite = item.optBoolean("isFavorite"),
                    sourceIdentifier = item.optString("sourceIdentifier").ifEmpty { null }
                )
            }.orEmpty()

            ChatState(
                people = people,
                tags = tags,
                messages = messages,
                selectedPersonId = null
            )
        }.getOrElse { if (withSeed) defaultState() else ChatState() }
    }

    private fun defaultState(): ChatState {
        val food = ChatTag(name = "食物爱好", symbolName = "restaurant")
        val todo = ChatTag(name = "Todo", symbolName = "check_circle")
        val promise = ChatTag(name = "约定一起做", symbolName = "event")
        val person = ChatPerson(name = "示例联系人", subtitle = "先导入聊天记录，再绑QQ/小红书/抖音")

        return ChatState(
            people = listOf(person),
            tags = listOf(food, todo, promise),
            selectedPersonId = person.id
        )
    }

    private fun save() {
        val root = JSONObject().put("schemaVersion", 2)
        root.put("people", JSONArray().apply {
            state.people.forEach {
                put(JSONObject().put("id", it.id).put("name", it.name).put("subtitle", it.subtitle))
            }
        })
        root.put("tags", JSONArray().apply {
            state.tags.forEach {
                put(
                    JSONObject().put("id", it.id)
                        .put("name", it.name)
                        .put("symbolName", it.symbolName)
                )
            }
        })
        root.put("messages", JSONArray().apply {
            state.messages.forEach { message ->
                put(
                    JSONObject()
                        .put("id", message.id)
                        .put("personId", message.personId)
                        .put("platform", message.platform.name)
                        .put("sender", message.sender.name)
                        .put("sentAtMillis", message.sentAtMillis)
                        .put("text", message.text)
                        .putOpt("externalTitle", message.externalTitle)
                        .putOpt("externalUrl", message.externalUrl)
                        .put("tagIds", JSONArray().apply { message.tagIds.forEach(::put) })
                        .put("isFavorite", message.isFavorite)
                        .putOpt("sourceIdentifier", message.sourceIdentifier)
                )
            }
        })

        val temporary = File(storeDirectory, "store.json.tmp")
        temporary.writeText(root.toString(2))
        if (!temporary.renameTo(storeFile)) {
            storeFile.writeText(root.toString(2))
            temporary.delete()
        }
    }

    private fun copySupportedFiles(source: DocumentFile, destination: File) {
        source.listFiles().forEach { item ->
            val name = item.name ?: return@forEach
            if (item.isDirectory) {
                val child = File(destination, name).apply { mkdirs() }
                copySupportedFiles(item, child)
            } else if (item.isFile && name.substringAfterLast('.', "").lowercase() in listOf("db", "json", "jsonl", "zip")) {
                copyUriToCache(item.uri, name, destination)
            }
        }
    }

    private fun copyUriToCache(uri: Uri, displayName: String, directory: File = context.cacheDir): File {
        directory.mkdirs()
        val target = File(directory, displayName.substringAfterLast('/').ifEmpty { "import.db" })
        context.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> output.write(input.readBytes()) }
        } ?: error("无法读取文件")
        return target
    }

    private fun queryDisplayName(uri: Uri): String? = runCatching {
        context.contentResolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    }.getOrNull()

    private fun uniqueFileName(name: String): String {
        val safe = name.ifBlank { "import" }
        return "${System.currentTimeMillis()}-$safe"
    }

    private inline fun <T> JSONArray.mapObject(transform: JSONArray.(Int) -> T): List<T> {
        return (0 until length()).map { transform(it) }
    }

    private inline fun <T> JSONArray.mapIndex(transform: JSONArray.(Int) -> T): List<T> {
        return (0 until length()).map { transform(it) }
    }

    companion object {
        private const val KEY_WATCHED_DIRECTORY = "watched_directory"
    }
}

data class ImportOutcome(
    val success: Boolean,
    val message: String
)
