package com.nativebrik.sdk.component.bridge

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.component.provider.data.DataContext
import com.nativebrik.sdk.component.provider.event.LocalEventListener
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

// forcefully dispatch uiblock event in the page compose context, from anywhere.
// dispatch(event) in flutter -> listen the event in the page context, and dispatch event from the page.
public class UIBlockEventBridgeViewModel : ViewModel() {
    private val _events = MutableSharedFlow<UIBlockEventDispatcher>()
    internal val events: SharedFlow<UIBlockEventDispatcher> = _events

    suspend fun dispatch(event: String) {
        val json = Json.decodeFromString<JsonElement>(event)
        val dispatcher = UIBlockEventDispatcher.decode(json) ?: return
        _events.emit(dispatcher)
    }
}

// Watch the event stream, and when it has events, then dispatch them.
// This composable won't render anything.
@DelicateCoroutinesApi
@Composable
internal fun UIBlockEventBridgeCollector(
    events: SharedFlow<UIBlockEventDispatcher>?,
    isCurrentPage: Boolean
) {
    val container = ContainerContext.value
    val data = DataContext.state.data
    val eventListener = LocalEventListener.current
    LaunchedEffect(Unit) {
        if (!isCurrentPage) {
            return@LaunchedEffect
        }

        events?.collect { event ->
            val req = event.httpRequest
            if (req != null) {
                GlobalScope.launch(Dispatchers.IO) {
                    container
                        .sendHttpRequest(req, data)
                        .onSuccess {
                            GlobalScope.launch(Dispatchers.Main) {
                                eventListener.dispatch(event, data)
                            }
                        }
                        .onFailure {
                            GlobalScope.launch(Dispatchers.Main) {
                                eventListener.dispatch(event, data)
                            }
                        }
                }
            } else {
                eventListener.dispatch(event, data)
            }
        }
    }
    return Unit
}
