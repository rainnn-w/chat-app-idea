package com.rainnn.chatmemory.android.data

import java.util.UUID

enum class ChatPlatform(val displayName: String) {
    WECHAT("微信"),
    QQ("QQ"),
    XIAOHONGSHU("小红书"),
    DOUYIN("抖音")
}

enum class MessageSender(val displayName: String) {
    ME("我"),
    PEER("对方"),
    SYSTEM("系统")
}

data class ChatPerson(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val subtitle: String
)

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val personId: String,
    val platform: ChatPlatform,
    val sender: MessageSender,
    val sentAtMillis: Long,
    val text: String,
    val externalTitle: String? = null,
    val externalUrl: String? = null,
    val tagIds: Set<String> = emptySet(),
    val isFavorite: Boolean = false,
    val sourceIdentifier: String? = null
) {
    val dedupSignature: String
        get() = listOf(
            platform.name,
            sourceIdentifier?.lowercase().orEmpty(),
            sentAtMillis,
            text.trim().lowercase(),
            externalTitle?.lowercase().orEmpty(),
            externalUrl?.lowercase().orEmpty()
        ).joinToString("|")
}

data class ChatTag(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val symbolName: String
)

data class ChatState(
    val people: List<ChatPerson> = emptyList(),
    val messages: List<ChatMessage> = emptyList(),
    val tags: List<ChatTag> = emptyList(),
    val selectedPersonId: String? = null,
    val selectedTagId: String? = null,
    val searchText: String = "",
    val selectedPlatforms: Set<ChatPlatform> = ChatPlatform.entries.toSet(),
    val selectedMessageId: String? = null,
    val importSummary: String? = null,
    val errorMessage: String? = null,
    val automationStatus: String = "尚未选择自动扫描目录",
    val watchedDirectoryUri: String? = null
) {
    val selectedPerson: ChatPerson?
        get() = people.firstOrNull { it.id == selectedPersonId }

    val selectedMessage: ChatMessage?
        get() = messages.firstOrNull { it.id == selectedMessageId }

    val visibleMessages: List<ChatMessage>
        get() {
            val query = searchText.trim().lowercase()
            val activeTagId = selectedTagId
            return messages.asSequence()
                .filter { selectedPersonId == null || it.personId == selectedPersonId }
                .filter { it.platform in selectedPlatforms }
                .filter { activeTagId == null || activeTagId in it.tagIds }
                .filter { message ->
                    query.isBlank() || listOf(
                        message.text,
                        message.externalTitle,
                        message.externalUrl,
                        people.firstOrNull { person -> person.id == message.personId }?.name
                    ).any { field -> field.orEmpty().lowercase().contains(query) }
                }
                .sortedByDescending { it.sentAtMillis }
                .toList()
        }

    fun messagesWithTag(tagId: String): List<ChatMessage> =
        messages.filter { tagId in it.tagIds }.sortedByDescending { it.sentAtMillis }
}
