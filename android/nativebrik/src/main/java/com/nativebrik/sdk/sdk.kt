package com.nativebrik.sdk

import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.component.Embedding
import com.nativebrik.sdk.component.EmbeddingLoadingState
import com.nativebrik.sdk.component.Trigger
import com.nativebrik.sdk.component.TriggerViewModel
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.ContainerImpl
import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.remoteconfig.RemoteConfigLoadingState

data class Endpoint(
    val cdn: String = "https://cdn.nativebrik.com",
    val track: String = "https://track.nativebrik.com/track/v1",
)

public data class Config(
    val projectId: String,
    val endpoint: Endpoint = Endpoint()
)

public data class NativebrikEvent(
    val name: String
)

internal var LocalNativebrikClient = compositionLocalOf<NativebrikClient> {
    error("NativebrikClient is not found")
}

public object Nativebrik {
    /**
     * Retrieves the current [NativebrikClient] at the call site's position in the hierarchy.
     */
    val client: NativebrikClient
        @Composable
        @ReadOnlyComposable
        get() = LocalNativebrikClient.current
}

@Composable
public fun NativebrikProvider(
    client: NativebrikClient,
    content: @Composable() () -> Unit
    ) {
    CompositionLocalProvider(
        LocalNativebrikClient provides client
    ) {
        client.experiment.Overlay()
        content()
    }
}


public class NativebrikClient {
    private final val config: Config
    public final val user: NativebrikUser
    public final val experiment: NativebrikExperiment

    public constructor(config: Config, context: Context) {
        this.config = config
        this.user = NativebrikUser(context)
        this.experiment = NativebrikExperiment(
            config = this.config,
            user = this.user,
            context = context,
        )
    }
}

public class NativebrikExperiment {
    private val container: Container
    private val trigger: TriggerViewModel

    internal constructor(config: Config, user: NativebrikUser, context: Context) {
        this.container = ContainerImpl(
            config = config,
            user = user,
            context = context,
        )
        this.trigger = TriggerViewModel(this.container)
    }

    public fun dispatch(event: NativebrikEvent) {
        this.trigger.dispatch(event)
    }

    @Composable
    public fun Overlay() {
        Trigger(trigger = this.trigger)
    }

    @Composable
    public fun Embedding(id: String, modifier: Modifier = Modifier) {
        Embedding(container = this.container, id, modifier = modifier) { state ->
            AnimatedContent(
                targetState = state,
                label = "",
                transitionSpec = {
                    fadeIn() togetherWith fadeOut()
                }
            ) { state ->
                when (state) {
                    is EmbeddingLoadingState.Completed -> state.view()
                    is EmbeddingLoadingState.Loading -> Row(
                        modifier = Modifier.fillMaxSize(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator()
                    }
                    else -> Row(
                        modifier = Modifier.fillMaxSize(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        BasicText(text = "Not Found")
                    }
                }
            }
        }
    }

    @Composable
    public fun RemoteConfig(id: String, content: @Composable (RemoteConfigLoadingState) -> Unit) {
        return com.nativebrik.sdk.remoteconfig.RemoteConfigView(
            container = this.container,
            experimentId = id,
            content = content
        )
    }

    public fun remoteConfig(id: String): com.nativebrik.sdk.remoteconfig.RemoteConfig {
        return com.nativebrik.sdk.remoteconfig.RemoteConfig(
            container = this.container,
            experimentId = id,
        )
    }
}
