package com.nativebrik.sdk.component

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
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
internal fun rememberEmbeddingState(container: Container, experimentId: String, componentId: String?): EmbeddingLoadingState {
    var loadingState: EmbeddingLoadingState by remember { mutableStateOf(EmbeddingLoadingState.Loading()) }
    LaunchedEffect("key") {
        container.fetchEmbedding(experimentId, componentId).onSuccess {
            loadingState = when (it) {
                is UIBlock.UnionUIRootBlock -> {
                    EmbeddingLoadingState.Completed {
                        Root(
                            container = container,
                            root = it.data,
                            modifier = Modifier.fillMaxHeight().fillMaxWidth()
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
    content: (@Composable() (state: EmbeddingLoadingState) -> Unit)?
) {
    val state = rememberEmbeddingState(container, experimentId, componentId)
    val render = content ?: { state ->
        when (state) {
            is EmbeddingLoadingState.Completed -> state.view()
            else -> {}
        }
    }

    Box(modifier = modifier) {
        render(state)
    }
}
