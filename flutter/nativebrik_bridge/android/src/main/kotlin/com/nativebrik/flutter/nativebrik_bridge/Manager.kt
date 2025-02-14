package com.nativebrik.flutter.nativebrik_bridge

import android.content.Context
import com.nativebrik.sdk.NativebrikClient
import com.nativebrik.sdk.__DO_NOT_USE_THIS_INTERNAL_BRIDGE
import com.nativebrik.sdk.data.NotFoundException
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import android.view.View
import android.widget.LinearLayout
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import com.nativebrik.sdk.NativebrikEvent
import com.nativebrik.sdk.remoteconfig.RemoteConfigVariant
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

internal data class ConfigEntity(val variant: RemoteConfigVariant?, val experimentId: String?)

internal class NativebrikBridgeManager(private val binaryMessenger: BinaryMessenger) {
    private var nativebrikClient: NativebrikClient? = null
    private var bridgeClient: __DO_NOT_USE_THIS_INTERNAL_BRIDGE? = null

    private var embeddingMap: MutableMap<String, Any?> = mutableMapOf()
    private var configMap: MutableMap<String, ConfigEntity> = mutableMapOf()

    fun setNativebrikClient(client: NativebrikClient) {
        this.nativebrikClient = client
        this.bridgeClient = __DO_NOT_USE_THIS_INTERNAL_BRIDGE(client)
    }

    fun getUserId(): String? {
        return this.nativebrikClient?.user.id
    }

    fun setUserProperties(properties: Map<String, String>) {
        this.nativebrikClient?.user.setProperties(properties)
    }

    fun getUserProperties(): Map<String, String>? {
        return this.nativebrikClient?.user.getProperties()
    }

    // embedding
    @OptIn(DelicateCoroutinesApi::class)
    fun connectEmbedding(channelId: String, experimentId: String, componentId: String? = null) {
        val methodChannel = MethodChannel(this.binaryMessenger, "Nativebrik/Embedding/$channelId")
        GlobalScope.launch(Dispatchers.IO) {
            val result = bridgeClient?.connectEmbedding(experimentId, componentId)
            if (result == null) {
                GlobalScope.launch(Dispatchers.Main) {
                    methodChannel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, "not-found")
                }
                return@launch
            }
            result.onSuccess {
                embeddingMap[channelId] = it
                GlobalScope.launch(Dispatchers.Main) {
                    methodChannel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, "completed")
                }
            }.onFailure {
                when (it) {
                    is NotFoundException -> {
                        GlobalScope.launch(Dispatchers.Main) {
                            methodChannel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, "not-found")
                        }
                    }
                    else -> {
                        GlobalScope.launch(Dispatchers.Main) {
                            methodChannel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, "failed")
                        }
                    }
                }
            }
        }
    }

    fun disconnectEmbedding(channelId: String) {
        embeddingMap.remove(channelId)
    }

    @Composable
    fun Render(channelId: String, arguments: Any?, modifier: Modifier = Modifier) {
        if (channelId.isEmpty()) {
            return
        }
        val bridgeClient = this.bridgeClient ?: return
        val methodChannel = remember(channelId) {
            MethodChannel(this.binaryMessenger, "Nativebrik/Embedding/$channelId")
        }
        val data = this.embeddingMap[channelId]
        bridgeClient.render(modifier, arguments, data, onEvent = { event ->
            methodChannel.invokeMethod(ON_EVENT_METHOD, mapOf(
                "name" to event.name,
                "deepLink" to event.deepLink,
                "payload" to event.payload?.map { prop ->
                    mapOf(
                        "name" to prop.name,
                        "value" to prop.value,
                        "type" to prop.type,
                    )
                }
            ))
        })
    }

    @Composable
    fun RenderOverlay() {
        nativebrikClient?.experiment?.Overlay()
    }

    // remote config
    suspend fun connectRemoteConfig(channelId: String, experimentId: String): Result<String> {
        if (channelId.isEmpty()) {
            return Result.success("not-found")
        }
        this.configMap[channelId] = ConfigEntity(null, null)

        if (experimentId.isEmpty()) {
            return Result.success("not-found")
        }
        val client = this.nativebrikClient ?: return Result.success("not-found")
        val config = client.experiment.remoteConfig(experimentId)
        val variant = config.fetch().getOrElse {
            val status = when (it) {
                is NotFoundException -> "not-found"
                else -> "failed"
            }
            return Result.success(status)
        }
        if (this.configMap[channelId] != null) {
            this.configMap[channelId] = ConfigEntity(variant, variant.experimentId)
        }
        return Result.success("competed")
    }

    fun disconnectRemoteConfig(channelId: String) {
        this.configMap.remove(channelId)
    }

    fun getRemoteConfigValue(channelId: String, key: String): String? {
        if (channelId.isEmpty()) return null
        if (key.isEmpty()) return null
        val config = this.configMap[channelId] ?: return null
        val variant = config.variant ?: return null
        return variant.get(key)
    }

    fun connectEmbeddingInRemoteConfigValue(channelId: String, key: String, embeddingChannelId: String) {
        if (channelId.isEmpty()) return
        val config = this.configMap[channelId] ?: return
        val variant = config.variant ?: return
        val componentId = variant.get(key) ?: return
        val experimentId = config.experimentId ?: return
        this.connectEmbedding(embeddingChannelId, experimentId, componentId)
    }

    fun dispatch(name: String) {
        this.nativebrikClient?.experiment?.dispatch(NativebrikEvent(name))
    }
}

internal class OverlayViewFactory(private val manager: NativebrikBridgeManager): PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return OverlayView(context, manager)
    }
}

internal class OverlayView(context: Context, manager: NativebrikBridgeManager): PlatformView {
    private val view: ComposeView

    override fun getView(): View {
        return view
    }

    override fun dispose() {}

    init {
        view = ComposeView(context).apply {
            setContent {
                manager.RenderOverlay()
            }
        }
    }
}

internal class NativeViewFactory(private val manager: NativebrikBridgeManager): PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<*, *>?
        val channelId = creationParams?.get("channelId") as String
        val arguments = creationParams["arguments"]
        return NativeView(context, channelId, arguments, manager)
    }
}

internal class NativeView(context: Context, channelId: String, arguments: Any?, manager: NativebrikBridgeManager): PlatformView {
    private val view: ComposeView

    override fun getView(): View {
        return view
    }

    override fun dispose() {}

    init {
        val param = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT)
        view = ComposeView(context).apply {
            setContent {
                manager.Render(channelId, arguments)
            }
            layoutParams = param
        }
    }
}