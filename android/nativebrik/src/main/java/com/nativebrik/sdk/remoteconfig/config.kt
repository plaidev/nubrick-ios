package com.nativebrik.sdk.remoteconfig

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.nativebrik.sdk.component.Embedding
import com.nativebrik.sdk.component.EmbeddingLoadingState
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.NotFoundException
import com.nativebrik.sdk.schema.ExperimentVariant

sealed class RemoteConfigLoadingState {
    class Loading(): RemoteConfigLoadingState()
    class Completed(var variant: RemoteConfigVariant): RemoteConfigLoadingState()
    class NotFound(): RemoteConfigLoadingState()
    class Failed(e: Throwable): RemoteConfigLoadingState()
}

@Composable
internal fun rememberRemoteConfigState(
    container: Container,
    experimentId: String
): RemoteConfigLoadingState {
    var loadingState: RemoteConfigLoadingState by remember { mutableStateOf(RemoteConfigLoadingState.Loading()) }
    LaunchedEffect("key") {
        container.fetchRemoteConfig(experimentId).onSuccess {
            loadingState = RemoteConfigLoadingState.Completed(RemoteConfigVariant(
                container = container,
                experimentId = experimentId,
                variant = it,
            ))
        }.onFailure {
            when (it) {
                is NotFoundException -> {
                    loadingState = RemoteConfigLoadingState.NotFound()
                }
                else -> {
                    loadingState = RemoteConfigLoadingState.Failed(it)
                }
            }
        }
    }
    return loadingState
}

class RemoteConfigVariant internal constructor(
    private val container: Container,
    private val experimentId: String,
    private val variant: ExperimentVariant
) {
    fun get(key: String): String? {
        val config = this.variant.configs?.firstOrNull { config ->
            config.key == key
        }
        return config?.value
    }

    fun getAsString(key: String): String? {
        return this.get(key)
    }

    fun getAsBoolean(key: String): Boolean? {
        return this.get(key)?.let {
            it == "TRUE"
        }
    }

    fun getAsInt(key: String): Int? {
        return this.get(key)?.let {
            try {
                it.toIntOrNull()
            } catch (_: Exception) {
                null
            }
        }
    }

    fun getAsFloat(key: String): Float? {
        return this.get(key)?.let {
            try {
                it.toFloatOrNull()
            } catch (_: Exception) {
                null
            }
        }
    }

    fun getAsDouble(key: String): Double? {
        return this.get(key)?.let {
            try {
                it.toDoubleOrNull()
            } catch (_: Exception) {
                null
            }
        }
    }

    @Composable
    fun GetAsEmbedding(
        key: String,
        content: (@Composable() (state: EmbeddingLoadingState) -> Unit)?
    ) {
        val componentId = this.get(key) ?: return
        return Embedding(
            container = this.container,
            experimentId = this.experimentId,
            componentId = componentId,
            content = content,
        )
    }
}

@Composable
internal fun RemoteConfigView(
    container: Container,
    experimentId: String,
    content: @Composable() (state: RemoteConfigLoadingState) -> Unit
) {
    val state = rememberRemoteConfigState(container = container, experimentId = experimentId)
    content(state)
}

class RemoteConfig internal constructor(
    private val container: Container,
    private val experimentId: String
) {
    suspend fun fetch(): Result<RemoteConfigVariant> {
        val variant = this.container.fetchRemoteConfig(experimentId).getOrElse {
            return Result.failure(it)
        }
        return Result.success(RemoteConfigVariant(
            container = this.container,
            experimentId = this.experimentId,
            variant = variant,
        ))
    }
}