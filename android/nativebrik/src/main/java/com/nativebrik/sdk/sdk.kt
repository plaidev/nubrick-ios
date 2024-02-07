package com.nativebrik.sdk

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.component.Embedding
import com.nativebrik.sdk.component.EmbeddingLoadingState
import com.nativebrik.sdk.component.renderer.Flex
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.ContainerImpl
import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.schema.UIFlexContainerBlock

data class Endpoint(
    val cdn: String = "https://cdn.nativebrik.com",
    val track: String = "https://track.nativebrik.com/track/v1",
) {}

data class Config(
    val projectId: String,
    val endpoint: Endpoint = Endpoint()
) {}

var LocalNativebrikClient = compositionLocalOf<NativebrikClient> {
    error("NativebrikClient is not found")
}

@Composable
public fun NativebrikProvider(
    client: NativebrikClient,
    content: @Composable() () -> Unit
    ) {
    CompositionLocalProvider(
        LocalNativebrikClient provides client
    ) {
        content()
    }
}


public class NativebrikClient {
    private final val config: Config
    private final val user: NativebrikUser
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
    internal constructor(config: Config, user: NativebrikUser, context: Context) {
        this.container = ContainerImpl(
            config = config,
            user = user,
            context = context,
        )
    }

    @Composable
    public fun embedding() {
        Flex(block = UIFlexContainerBlock(id = null, data = null)) {
            BasicText(text = "ToToToToTo")
            BasicText(text = "ToToToToTo")

            BasicText(text = "ToToToToTo")
        }
    }

    @Composable
    public fun embedding2(id: String, modifier: Modifier = Modifier) {
        Embedding(container = this.container, id, modifier) { state ->
            when (state) {
                is EmbeddingLoadingState.Completed -> state.view()
                is EmbeddingLoadingState.Loading -> Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    BasicText(text = "Loading")
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

    fun remoteConfig() {}
}
