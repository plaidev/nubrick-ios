package com.nativebrik.sdk.component

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.Event
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.NotFoundException
import com.nativebrik.sdk.schema.UIBlock

sealed class EmbeddingLoadingState {
    class Loading(): EmbeddingLoadingState()
    class Completed(var view: @Composable() () -> Unit): EmbeddingLoadingState()
    class NotFound(): EmbeddingLoadingState()
    class Failed(e: Throwable): EmbeddingLoadingState()
}

@Composable
internal fun rememberEmbeddingState(container: Container, experimentId: String, componentId: String?, onEvent: ((event: Event) -> Unit)?): EmbeddingLoadingState {
    var loadingState: EmbeddingLoadingState by remember { mutableStateOf(EmbeddingLoadingState.Loading()) }
    LaunchedEffect("key") {
        container.fetchEmbedding(experimentId, componentId).onSuccess {
            loadingState = when (it) {
                is UIBlock.UnionUIRootBlock -> {
                    EmbeddingLoadingState.Completed {
                        Root(
                            container = container,
                            root = it.data,
                            modifier = Modifier
                                .fillMaxSize(),
                            onEvent = onEvent ?: {}
                        )
                    }
                }

                else -> {
                    EmbeddingLoadingState.NotFound()
                }
            }
        }.onFailure {
            loadingState = when (it) {
                is NotFoundException -> {
                    EmbeddingLoadingState.NotFound()
                }

                else -> {
                    EmbeddingLoadingState.Failed(it)
                }
            }
        }
    }
    return loadingState
}

@Composable
internal fun Embedding(
    container: Container,
    experimentId: String,
    componentId: String? = null,
    modifier: Modifier = Modifier,
    onEvent: ((event: Event) -> Unit)? = null,
    content: (@Composable() (state: EmbeddingLoadingState) -> Unit)?
) {
    val state = rememberEmbeddingState(container, experimentId, componentId, onEvent)
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        AnimatedContent(
            targetState = state,
            label = "EmbeddingLoadingStateAnimation",
            transitionSpec = {
                fadeIn() togetherWith fadeOut()
            },
            modifier = Modifier.fillMaxSize()
        ) { state ->
            Row(
                modifier = Modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                when (state) {
                    is EmbeddingLoadingState.Completed -> if (content != null) content(state) else state.view()
                    is EmbeddingLoadingState.Loading -> if (content != null) content(state) else CircularProgressIndicator()
                    else -> if (content != null) content(state) else Unit
                }
            }
        }
    }
}
