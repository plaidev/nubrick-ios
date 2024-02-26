package com.nativebrik.sdk.component.provider.event

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.component.provider.data.DataContext
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

private var LocalEventListener = compositionLocalOf<EventListenerState> {
    error("LocalEventListener is not found")
}

internal data class EventListenerState(
    internal val listener: (event: UIBlockEventDispatcher) -> Unit
) {
    fun dispatch(event: UIBlockEventDispatcher) {
        this.listener(event)
    }
}

@Composable
internal fun rememberEventListenerState(
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
internal fun EventListenerProvider(
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
internal fun Modifier.eventDispatcher(eventDispatcher: UIBlockEventDispatcher?): Modifier {
    return composed {
        val scope = rememberCoroutineScope()
        val container = ContainerContext.value
        val data = DataContext.state.data
        val eventListener = LocalEventListener.current
        val event = eventDispatcher ?: return@composed this
        this.clickable(true) {
            val req = event.httpRequest
            if (req != null) {
                scope.launch(Dispatchers.IO) {
                    container
                        .sendHttpRequest(req, data)
                        .onSuccess {
                            scope.launch(Dispatchers.Main) {
                                eventListener.dispatch(event)
                            }
                        }
                        .onFailure {
                            scope.launch(Dispatchers.Main) {
                                eventListener.dispatch(event)
                            }
                        }
                }
            } else {
                eventListener.dispatch(event)
            }
        }
    }
}

@Composable
internal fun Modifier.skeleton(enable: Boolean = false): Modifier {
    return composed {
        if (!enable) return@composed this

        val skeletonColors = listOf(
            Color.Black.copy(alpha = 0.08f),
            Color.Black.copy(alpha = 0.09f),
            Color.Black.copy(alpha = 0.11f),
            Color.Black.copy(alpha = 0.09f),
            Color.Black.copy(alpha = 0.08f),
        )
        val width = 500
        val duration = 1000
        val transition = rememberInfiniteTransition(label = "Skeleton loading transition")
        val translateAnimation = transition.animateFloat(
            initialValue = 0f,
            targetValue = (duration.toFloat() + width.toFloat()),
            animationSpec = infiniteRepeatable(
                animation = tween(duration, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "Skeleton loading animation"
        )
        this.background(
            brush = Brush.linearGradient(
                colors = skeletonColors,
                start = Offset(x = translateAnimation.value - width, y = 0.0f),
                end = Offset(x = translateAnimation.value, y = 270f),
            )
        )
    }
}
