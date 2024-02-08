package com.nativebrik.sdk.component.provider.event

import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.UIBlockEventDispatcher

var LocalEventListener = compositionLocalOf<EventListenerState> {
    error("LocalEventListener is not found")
}

data class EventListenerState(
    val listener: (event: UIBlockEventDispatcher) -> Unit
) {
    fun dispatch(event: UIBlockEventDispatcher) {
        this.listener(event)
    }
}

@Composable
fun rememberEventListenerState(
    listener: (event: UIBlockEventDispatcher) -> Unit
): EventListenerState {
    var state: EventListenerState by remember {
        mutableStateOf(EventListenerState(listener))
    }
    return remember(state) {
        state
    }
}

@Composable
fun EventListenerProvider(
    listener: (event: UIBlockEventDispatcher) -> Unit,
    content: @Composable() () -> Unit,
) {
    val state = rememberEventListenerState(listener)
    CompositionLocalProvider(
        LocalEventListener provides state
    ) {
        content()
    }
}

@Composable
fun eventDiaptcherModifier(modifier: Modifier, eventDispatcher: UIBlockEventDispatcher?): Modifier {
    val eventListener = LocalEventListener.current
    val eventDispatcher = eventDispatcher ?: return modifier
    return modifier.clickable(enabled = true) {
        eventListener.listener(eventDispatcher)
    }
}