package com.rainnn.chatmemory.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Contacts
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import com.rainnn.chatmemory.android.data.ChatRepository

private enum class AppTab(val title: String) {
    TIMELINE("时间线"),
    TAGS("标签"),
    PEOPLE("联系人"),
    SETTINGS("设置")
}

@Composable
fun ChatMemoryApp(repository: ChatRepository) {
    val state = repository.state
    var selectedTab by remember { mutableIntStateOf(0) }
    val configuration = LocalConfiguration.current
    val wideLayout = configuration.screenWidthDp >= 640

    LaunchedEffect(state.watchedDirectoryUri) {
        if (state.watchedDirectoryUri != null) {
            repository.refreshWatchedDirectory(state.selectedPersonId)
        }
    }

    ChatMemoryTheme {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.05f),
                                MaterialTheme.colorScheme.background,
                                MaterialTheme.colorScheme.secondary.copy(alpha = 0.04f)
                            )
                        )
                    )
            ) {
                if (wideLayout) {
                    Row(Modifier.fillMaxSize()) {
                        NavigationRail(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f)) {
                            AppTab.entries.forEachIndexed { index, tab ->
                                NavigationRailItem(
                                    selected = selectedTab == index,
                                    onClick = { selectedTab = index },
                                    icon = {
                                        Icon(tab.icon(), contentDescription = tab.title)
                                    },
                                    label = { Text(tab.title) }
                                )
                            }
                        }
                        Box(Modifier.weight(1f)) {
                            AppDestination(selectedTab, repository, state)
                        }
                    }
                } else {
                    Column(Modifier.fillMaxSize()) {
                        Box(Modifier.weight(1f)) {
                            AppDestination(selectedTab, repository, state)
                        }
                        NavigationBar(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f)) {
                            AppTab.entries.forEachIndexed { index, tab ->
                                NavigationBarItem(
                                    selected = selectedTab == index,
                                    onClick = { selectedTab = index },
                                    icon = { Icon(tab.icon(), contentDescription = tab.title) },
                                    label = { Text(tab.title) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AppDestination(
    index: Int,
    repository: ChatRepository,
    state: com.rainnn.chatmemory.android.data.ChatState
) {
    when (index) {
        0 -> TimelineScreen(repository, state)
        1 -> TagsScreen(repository, state)
        2 -> PeopleScreen(repository, state)
        else -> SettingsScreen(repository, state)
    }
}

private fun AppTab.icon() = when (this) {
    AppTab.TIMELINE -> Icons.Filled.Forum
    AppTab.TAGS -> Icons.Filled.Tag
    AppTab.PEOPLE -> Icons.Filled.Contacts
    AppTab.SETTINGS -> Icons.Filled.Settings
}
