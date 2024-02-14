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
import com.nativebrik.sdk.schema.UIBlock

data class EmbeddingState(
    val state: EmbeddingLoadingState,
)

sealed class EmbeddingLoadingState {
    class Loading(): EmbeddingLoadingState()
    class Completed(var view: @Composable() () -> Unit): EmbeddingLoadingState()
    class NotFound(): EmbeddingLoadingState()
    class Failed(e: Throwable): EmbeddingLoadingState()
}


@Composable
fun rememberEmbeddingState(container: Container, experimentId: String): EmbeddingState {
    var loadingState: EmbeddingLoadingState by remember { mutableStateOf(EmbeddingLoadingState.Loading()) }
    LaunchedEffect("key") {
        container.fetchEmbedding(experimentId).onSuccess {
            when (it) {
                is UIBlock.UnionUIRootBlock -> {
                    loadingState = EmbeddingLoadingState.Completed {
                        Root(
                            container = container,
                            root = it.data,
                            modifier = Modifier.fillMaxHeight().fillMaxWidth()
                        )
                    }
                }
                else -> {
                    loadingState = EmbeddingLoadingState.NotFound()
                }
            }
        }.onFailure {
            loadingState = EmbeddingLoadingState.Failed(it)
        }
    }
    return remember(loadingState) {
        EmbeddingState(
            state = loadingState,
        )
    }
}

@Composable
fun Embedding(
    container: Container,
    experimentId: String,
    modifier: Modifier = Modifier,
    content: (@Composable() (state: EmbeddingLoadingState) -> Unit)?
) {
    val state = rememberEmbeddingState(container, experimentId)
    val render = content ?: { state ->
        when (state) {
            is EmbeddingLoadingState.Completed -> state.view()
            else -> {}
        }
    }

    Box(modifier = modifier) {
        render(state.state)
    }
}
