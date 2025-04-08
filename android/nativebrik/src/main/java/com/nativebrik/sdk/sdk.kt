package com.nativebrik.sdk

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.component.Embedding
import com.nativebrik.sdk.component.EmbeddingLoadingState
import com.nativebrik.sdk.component.Root
import com.nativebrik.sdk.component.Trigger
import com.nativebrik.sdk.component.TriggerViewModel
import com.nativebrik.sdk.data.CacheStore
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.ContainerImpl
import com.nativebrik.sdk.data.database.NativebrikDbHelper
import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.remoteconfig.RemoteConfigLoadingState
import com.nativebrik.sdk.schema.UIBlock
import kotlin.time.Duration
import kotlin.time.DurationUnit
import kotlin.time.toDuration

const val VERSION = "0.4.0"

data class Endpoint(
    val cdn: String = "https://cdn.nativebrik.com",
    val track: String = "https://track.nativebrik.com/track/v1",
)

public enum class EventPropertyType {
    INTEGER,
    STRING,
    TIMESTAMPZ,
    UNKNOWN
}

public data class EventProperty(
    val name: String,
    val value: String,
    val type: EventPropertyType
)
public data class Event(
    val name: String?,
    val deepLink: String?,
    val payload: List<EventProperty>?
)

public data class Config(
    val projectId: String,
    val endpoint: Endpoint = Endpoint(),
    val onEvent: ((event: Event) -> Unit)? = null,
    val cachePolicy: CachePolicy = CachePolicy()
)

public enum class CacheStorage {
    IN_MEMORY
}

public data class CachePolicy(
    val cacheTime: Duration = 24.toDuration(DurationUnit.HOURS),
    val staleTime: Duration = Duration.ZERO,
    val storage: CacheStorage = CacheStorage.IN_MEMORY,
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
    private final val db: SQLiteDatabase
    public final val user: NativebrikUser
    public final val experiment: NativebrikExperiment

    public constructor(config: Config, context: Context) {
        this.config = config
        this.user = NativebrikUser(context)
        val helper = NativebrikDbHelper(context)
        this.db = helper.writableDatabase
        this.experiment = NativebrikExperiment(
            config = this.config,
            user = this.user,
            db = this.db,
            context = context,
        )
    }

    public fun close() {
        this.db.close()
    }
}

public class NativebrikExperiment {
    internal val container: Container
    private val trigger: TriggerViewModel

    internal constructor(config: Config, user: NativebrikUser, db: SQLiteDatabase, context: Context) {
        this.container = ContainerImpl(
            config = config.copy(onEvent = { event ->
                val name = event.name ?: ""
                if (name.isNotEmpty()) {
                    this.dispatch(NativebrikEvent(name))
                }
                config.onEvent?.let { it(event) }
            }),
            user = user,
            db = db,
            cache = CacheStore(config.cachePolicy),
            context = context,
        )
        this.trigger = TriggerViewModel(this.container, user)
    }

    public fun dispatch(event: NativebrikEvent) {
        this.trigger.dispatch(event)
    }

    public fun record(throwable: Throwable) {
        this.container.record(throwable)
    }

    @Composable
    public fun Overlay() {
        Trigger(trigger = this.trigger)
    }

    @Composable
    public fun Embedding(
        id: String,
        modifier: Modifier = Modifier,
        arguments: Any? = null,
        onEvent: ((event: Event) -> Unit)? = null,
        content: (@Composable() (state: EmbeddingLoadingState) -> Unit)? = null
    ) {
        Embedding(container = this.container.initWith(arguments), id, modifier = modifier, onEvent = onEvent, content = content)
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

public class __DO_NOT_USE_THIS_INTERNAL_BRIDGE(private val client: NativebrikClient) {
    suspend fun connectEmbedding(experimentId: String, componentId: String?): Result<Any?> {
        return client.experiment.container.fetchEmbedding(experimentId, componentId)
    }

    @Composable
    fun render(modifier: Modifier = Modifier, arguments: Any? = null, data: Any?, onEvent: ((event: Event) -> Unit)) {
        val container = remember(arguments) {
            client.experiment.container.initWith(arguments)
        }
        if (data is UIBlock.UnionUIRootBlock) {
            Row(
                modifier = modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Root(
                    modifier = Modifier.fillMaxSize(),
                    container = container,
                    root = data.data,
                    onEvent = onEvent,
                )
            }
        } else {
            Unit
        }
    }
}