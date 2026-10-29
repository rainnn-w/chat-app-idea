package com.rainnn.chatmemory.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.rainnn.chatmemory.android.data.ChatRepository
import com.rainnn.chatmemory.android.ui.ChatMemoryApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val repository = ChatRepository(applicationContext)
        setContent {
            ChatMemoryApp(repository)
        }
    }
}

