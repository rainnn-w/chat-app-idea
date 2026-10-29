package com.rainnn.chatmemory.android.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.rainnn.chatmemory.android.data.ChatPlatform

private val LightColors = lightColorScheme(
    primary = Color(0xFF6A5AE0),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE6E1FF),
    secondary = Color(0xFF00A884),
    tertiary = Color(0xFFF23859),
    background = Color(0xFFF5F5FA),
    surface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFFEDEDF5),
    outlineVariant = Color(0xFFDFDFE8)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB9B0FF),
    onPrimary = Color(0xFF1E1740),
    primaryContainer = Color(0xFF3B2F82),
    secondary = Color(0xFF63DBB2),
    tertiary = Color(0xFFFF8098),
    background = Color(0xFF0B0B11),
    surface = Color(0xFF15151C),
    surfaceVariant = Color(0xFF1F1F29),
    outlineVariant = Color(0xFF35353F)
)

@Composable
fun ChatMemoryTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val context = LocalContext.current
    val useDynamic = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val colors = when {
        useDynamic && darkTheme -> dynamicDarkColorScheme(context)
        useDynamic -> dynamicLightColorScheme(context)
        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(colorScheme = colors, content = content)
}

val ChatPlatformAccent = mapOf(
    ChatPlatform.WECHAT to Color(0xFF23B26D),
    ChatPlatform.QQ to Color(0xFF337DF7),
    ChatPlatform.XIAOHONGSHU to Color(0xFFF23859),
    ChatPlatform.DOUYIN to Color(0xFF54C9F0)
)
