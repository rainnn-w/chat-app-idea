package com.rainnn.chatmemory.android.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.UploadFile
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.rainnn.chatmemory.android.data.ChatMessage
import com.rainnn.chatmemory.android.data.ChatPlatform
import com.rainnn.chatmemory.android.data.ChatRepository
import com.rainnn.chatmemory.android.data.ChatState
import com.rainnn.chatmemory.android.data.ChatTag
import com.rainnn.chatmemory.android.data.MessageSender
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val timeFormatter = DateTimeFormatter.ofPattern("yyyy年MM月dd日 HH:mm")

private fun formattedTime(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(timeFormatter)

@Composable
private fun platformAccent(platform: ChatPlatform): Color =
    ChatPlatformAccent[platform] ?: MaterialTheme.colorScheme.primary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineScreen(repository: ChatRepository, state: ChatState) {
    var showCapture by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.padding(horizontal = 18.dp, vertical = 12.dp)) {
            OutlinedTextField(
                value = state.searchText,
                onValueChange = repository::setSearchText,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("全局搜索消息、链接、联系人") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                shape = RoundedCornerShape(18.dp),
                singleLine = true
            )

            Spacer(Modifier.height(10.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                AssistChip(
                    onClick = { repository.select(null) },
                    label = { Text("全部") },
                    leadingIcon = {
                        Icon(Icons.Filled.Person, contentDescription = null, Modifier.size(15.dp))
                    }
                )
                state.people.forEach { person ->
                    FilterChip(
                        selected = state.selectedPersonId == person.id,
                        onClick = { repository.select(person.id) },
                        label = { Text(person.name) }
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ChatPlatform.entries.forEach { platform ->
                    FilterChip(
                        selected = platform in state.selectedPlatforms,
                        onClick = { repository.togglePlatform(platform) },
                        label = { Text(platform.displayName) }
                    )
                }
            }

            state.importSummary?.let {
                Spacer(Modifier.height(10.dp))
                StatusBanner(it, false)
            }
            state.errorMessage?.let {
                Spacer(Modifier.height(10.dp))
                StatusBanner(it, true)
            }
            }

        if (state.visibleMessages.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyState(
                    icon = Icons.Filled.Forum,
                    title = "还没有匹配的记忆",
                    message = "选择联系人后导入 ChatLab JSON、抖音导出 JSON 或解密后的微信目录。"
                )
            }
        } else {
            LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 18.dp,
                    end = 18.dp,
                    top = 2.dp,
                    bottom = 96.dp
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(state.visibleMessages, key = { it.id }) { message ->
                    MessageTile(
                        message = message,
                        personName = state.people.firstOrNull { it.id == message.personId }?.name ?: "未绑定",
                        tags = state.tags.filter { tag -> tag.id in message.tagIds },
                        showPerson = state.selectedPersonId == null,
                        onClick = { repository.selectMessage(message.id) },
                        onFavorite = { repository.toggleFavorite(message) }
                    )
                }
            }
        }
        }

    ExtendedFloatingActionButton(
        onClick = { showCapture = true },
        modifier = Modifier
            .padding(20.dp)
            .align(Alignment.BottomEnd),
        icon = { Icon(Icons.Filled.Add, contentDescription = null) },
        text = { Text("补充消息") }
    )

    state.selectedMessage?.let { message ->
        ModalBottomSheet(onDismissRequest = { repository.selectMessage(null) }) {
            MessageDetail(repository, state, message)
        }
    }

    if (showCapture) {
        ManualMessageDialog(
            state = state,
            onDismiss = { showCapture = false },
            onSubmit = { platform, sender, text, url ->
                repository.addMessage(
                    platform = platform,
                    sender = sender,
                    text = text,
                    externalUrl = url
                )
                showCapture = false
            }
        )
    }

    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageTile(
    message: ChatMessage,
    personName: String,
    tags: List<ChatTag>,
    showPerson: Boolean,
    onClick: () -> Unit,
    onFavorite: () -> Unit
) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(Modifier.height(IntrinsicSize.Min)) {
            Box(
                Modifier
                    .width(5.dp)
                    .fillMaxHeight()
                    .background(platformAccent(message.platform))
            )
            Column(Modifier.weight(1f).padding(15.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            message.sender.displayName,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Black
                        )
                        Text(
                            if (showPerson) "$personName · ${message.platform.displayName}" else message.platform.displayName,
                            style = MaterialTheme.typography.labelSmall,
                            color = platformAccent(message.platform),
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    IconButton(onClick = onFavorite) {
                        Icon(
                            if (message.isFavorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = "收藏",
                            tint = if (message.isFavorite) MaterialTheme.colorScheme.tertiary
                            else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(Modifier.height(8.dp))
                Text(message.text, style = MaterialTheme.typography.bodyMedium)

                if (tags.isNotEmpty()) {
                    Spacer(Modifier.height(9.dp))
                    Row(
                        Modifier.horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        tags.forEach { tag ->
                            AssistChip(onClick = {}, label = { Text(tag.name) })
                        }
                    }
                }

                Spacer(Modifier.height(9.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        formattedTime(message.sentAtMillis),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f)
                    )
                    message.externalUrl?.let { url ->
                        IconLabel(
                            icon = Icons.AutoMirrored.Filled.OpenInNew,
                            text = "原帖",
                            tint = platformAccent(message.platform)
                        )
                        OpenLinkAction(url)
                    }
                }
            }
        }
    }
}

@Composable
private fun OpenLinkAction(url: String) {
    val context = LocalContext.current
    TextButton(onClick = {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    }) { Text("打开") }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageDetail(repository: ChatRepository, state: ChatState, message: ChatMessage) {
    val context = LocalContext.current
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
        Text(message.text, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Text(
            "${formattedTime(message.sentAtMillis)} · ${message.platform.displayName}",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(16.dp))
        Text("标签", fontWeight = FontWeight.Black)
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            state.tags.forEach { tag ->
                FilterChip(
                    selected = tag.id in message.tagIds,
                    onClick = { repository.toggleTag(tag, message) },
                    label = { Text(tag.name) }
                )
            }
        }
        message.externalUrl?.let { url ->
            Spacer(Modifier.height(16.dp))
            OutlinedButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }) {
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("跳转原帖")
            }
        }
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun ManualMessageDialog(
    state: ChatState,
    onDismiss: () -> Unit,
    onSubmit: (ChatPlatform, MessageSender, String, String?) -> Unit
) {
    var platform by remember { mutableStateOf(ChatPlatform.WECHAT) }
    var sender by remember { mutableStateOf(MessageSender.ME) }
    var text by remember { mutableStateOf("") }
    var url by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("补充一条消息") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    ChatPlatform.entries.forEach { item ->
                        FilterChip(
                            selected = platform == item,
                            onClick = { platform = item },
                            label = { Text(item.displayName) }
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    MessageSender.entries.forEach { item ->
                        FilterChip(
                            selected = sender == item,
                            onClick = { sender = item },
                            label = { Text(item.displayName) }
                        )
                    }
                }
                OutlinedTextField(value = text, onValueChange = { text = it }, label = { Text("内容") })
                OutlinedTextField(value = url, onValueChange = { url = it }, label = { Text("链接（可选）") })
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSubmit(platform, sender, text, url.ifBlank { null }) },
                enabled = state.selectedPersonId != null && text.isNotBlank()
            ) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TagsScreen(repository: ChatRepository, state: ChatState) {
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("人物标签", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
        }
        items(state.tags, key = { it.id }) { tag ->
            val count = state.messagesWithTag(tag.id).size
            Card(
                onClick = { repository.selectTag(if (state.selectedTagId == tag.id) null else tag.id) },
                colors = CardDefaults.cardColors(
                    containerColor = if (state.selectedTagId == tag.id) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.surface
                    }
                ),
                shape = RoundedCornerShape(22.dp)
            ) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Sell, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(tag.name, fontWeight = FontWeight.Black)
                        Text("$count 条记录", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        if (state.selectedTagId != null) {
            items(state.visibleMessages, key = { it.id }) { message ->
                MessageTile(
                    message = message,
                    personName = state.people.firstOrNull { it.id == message.personId }?.name ?: "未绑定",
                    tags = state.tags.filter { it.id in message.tagIds },
                    showPerson = true,
                    onClick = { repository.selectMessage(message.id) },
                    onFavorite = { repository.toggleFavorite(message) }
                )
            }
        }
    }
    state.selectedMessage?.let { message ->
        ModalBottomSheet(onDismissRequest = { repository.selectMessage(null) }) {
            MessageDetail(repository, state, message)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PeopleScreen(repository: ChatRepository, state: ChatState) {
    var showAdd by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var subtitle by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize().padding(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "联系人",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Black,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = { showAdd = true }) {
                Icon(Icons.Filled.Add, contentDescription = "添加联系人")
            }
        }
        Spacer(Modifier.height(12.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(state.people, key = { it.id }) { person ->
                val count = state.messages.count { it.personId == person.id }
                Card(
                    onClick = { repository.select(person.id) },
                    colors = CardDefaults.cardColors(
                        containerColor = if (state.selectedPersonId == person.id) {
                            MaterialTheme.colorScheme.primaryContainer
                        } else {
                            MaterialTheme.colorScheme.surface
                        }
                    ),
                    shape = RoundedCornerShape(22.dp)
                ) {
                    Row(Modifier.padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                        Avatar(person.name)
                        Spacer(Modifier.width(13.dp))
                        Column(Modifier.weight(1f)) {
                            Text(person.name, fontWeight = FontWeight.Black)
                            Text(
                                person.subtitle,
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        Text("$count", fontWeight = FontWeight.Black)
                    }
                }
            }
        }
    }

    if (showAdd) {
        AlertDialog(
            onDismissRequest = { showAdd = false },
            title = { Text("新联系人") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("姓名") })
                    OutlinedTextField(
                        value = subtitle,
                        onValueChange = { subtitle = it },
                        label = { Text("平台身份说明") }
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    repository.addPerson(name, subtitle)
                    name = ""
                    subtitle = ""
                    showAdd = false
                }) { Text("添加") }
            },
            dismissButton = { TextButton(onClick = { showAdd = false }) { Text("取消") } }
        )
    }
}

@Composable
fun SettingsScreen(repository: ChatRepository, state: ChatState) {
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            busy = true
            scope.launch {
                val result = repository.importUri(
                    uri,
                    context.contentResolver.queryDisplayNameCompat(uri),
                    state.selectedPersonId
                )
                busy = false
            }
        }
    }

    val directoryPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            repository.setWatchedDirectory(uri)
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("设置", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
        state.importSummary?.let { StatusBanner(it, false) }
        state.errorMessage?.let { StatusBanner(it, true) }

        SectionCard {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("导入", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black)
                Text("先绑定一个人，再导入同一人的其他平台记录。支持 WeChatDataAnalysis messages.json/ZIP、ChatLab JSON/JSONL、抖音导出 JSON、通用 JSON 和解密后的微信 SQLite。")
                OutlinedButton(
                    onClick = {
                        filePicker.launch(arrayOf("*/*"))
                    },
                    enabled = !busy && state.selectedPersonId != null
                ) {
                    Icon(Icons.Filled.UploadFile, contentDescription = null)
                    Spacer(Modifier.width(7.dp))
                    Text("选择导出文件")
                }
                OutlinedButton(
                    onClick = { directoryPicker.launch(null) },
                    enabled = !busy && state.selectedPersonId != null
                ) {
                    Icon(Icons.Filled.FolderOpen, contentDescription = null)
                    Spacer(Modifier.width(7.dp))
                    Text("选择解密微信目录")
                }
                OutlinedButton(
                    onClick = {
                        busy = true
                        scope.launch {
                            repository.importInbox(state.selectedPersonId)
                            busy = false
                        }
                    },
                    enabled = !busy && state.selectedPersonId != null
                ) {
                    Icon(Icons.Filled.Inbox, contentDescription = null)
                    Spacer(Modifier.width(7.dp))
                    Text("立即检查应用 Inbox")
                }
            }
        }

        SectionCard {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("自动扫描", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black)
                Text(state.watchedDirectoryUri ?: "尚未选择自动扫描目录")
                Text(state.automationStatus, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedButton(
                    onClick = { directoryPicker.launch(null) },
                    enabled = !busy
                ) {
                    Icon(Icons.Filled.AutoAwesome, contentDescription = null)
                    Spacer(Modifier.width(7.dp))
                    Text("绑定扫描目录")
                }
                OutlinedButton(
                    onClick = {
                        busy = true
                        scope.launch {
                            repository.refreshWatchedDirectory(state.selectedPersonId)
                            busy = false
                        }
                    },
                    enabled = !busy && state.watchedDirectoryUri != null
                ) {
                    Text("立即扫描")
                }
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MetricTile("联系人", "${state.people.size}", Modifier.weight(1f))
            MetricTile("消息", "${state.messages.size}", Modifier.weight(1f))
            MetricTile("标签", "${state.tags.size}", Modifier.weight(1f))
        }

        Text(
            "数据保存在应用私有目录。ChatMemory 只导入你主动选择的文件，不读取进程内存，不提取密钥，不上传聊天内容。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

private fun android.content.ContentResolver.queryDisplayNameCompat(uri: Uri): String? = runCatching {
    query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
        val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
    }
}.getOrNull()
