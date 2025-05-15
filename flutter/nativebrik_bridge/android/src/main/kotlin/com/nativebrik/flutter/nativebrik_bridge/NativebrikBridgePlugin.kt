package com.nativebrik.flutter.nativebrik_bridge

import android.content.Context
import android.provider.Settings.Global
import com.nativebrik.sdk.CachePolicy
import com.nativebrik.sdk.CacheStorage
import com.nativebrik.sdk.Config

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.nativebrik.sdk.VERSION
import com.nativebrik.sdk.NativebrikClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlin.coroutines.CoroutineContext
import kotlin.time.DurationUnit
import kotlin.time.toDuration

internal const val EMBEDDING_VIEW_ID = "nativebrik-embedding-view"
internal const val OVERLAY_VIEW_ID = "nativebrik-overlay-view"
internal const val EMBEDDING_PHASE_UPDATE_METHOD = "embedding-phase-update"
internal const val ON_EVENT_METHOD = "on-event"
internal const val ON_DISPATCH_METHOD = "on-dispatch"
internal const val ON_NEXT_TOOLTIP_METHOD = "on-next-tooltip"
internal const val ON_DISMISS_TOOLTIP_METHOD = "on-dismiss-tooltip"

/** NativebrikBridgePlugin */
class NativebrikBridgePlugin: FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private lateinit var manager: NativebrikBridgeManager

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = flutterPluginBinding.binaryMessenger
        manager = NativebrikBridgeManager(messenger)
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(messenger, "nativebrik_bridge")
        channel.setMethodCallHandler(this)

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            OVERLAY_VIEW_ID,
            OverlayViewFactory(manager)
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            EMBEDDING_VIEW_ID,
            NativeViewFactory(manager)
        )
    }

    @OptIn(DelicateCoroutinesApi::class)
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getNativebrikSDKVersion" -> {
                result.success(VERSION)
            }
            "connectClient" -> {
                val projectId = call.argument<String>("projectId") as String
                if (projectId.isEmpty()) {
                    result.success("no")
                    return
                }
                val cachePolicy = call.argument<Map<String, *>>("cachePolicy") as Map<String, *>
                if (cachePolicy.isEmpty()) {
                    result.success("no")
                    return
                }
                val cacheTime = cachePolicy["cacheTime"] as Int
                val staleTime = cachePolicy["staleTime"] as Int
                val storage = cachePolicy["storage"] as String
                val nativebrikCachePolicy = CachePolicy(
                        cacheTime = cacheTime.toDuration(DurationUnit.SECONDS),
                        staleTime = staleTime.toDuration(DurationUnit.SECONDS),
                        storage = if (storage == "inMemory") CacheStorage.IN_MEMORY else CacheStorage.IN_MEMORY
                    )
                val client = NativebrikClient(
                    Config(
                        projectId,
                        onEvent = { it ->
                            GlobalScope.launch(Dispatchers.Main) {
                                channel.invokeMethod(ON_EVENT_METHOD, mapOf(
                                    "name" to it.name,
                                    "deepLink" to it.deepLink,
                                    "payload" to it.payload?.map { prop ->
                                        mapOf(
                                            "name" to prop.name,
                                            "value" to prop.value,
                                            "type" to prop.type,
                                        )
                                    }
                                ))
                            }
                        },
                        cachePolicy = nativebrikCachePolicy,
                        onDispatch = { it ->
                            GlobalScope.launch(Dispatchers.Main) {
                                channel.invokeMethod(ON_DISPATCH_METHOD, mapOf(
                                    "name" to it.name
                                ))
                            }
                        }
                    ), context)
                this.manager.setNativebrikClient(client)
                result.success("ok")
            }
            "getUserId" -> {
                val userId = this.manager.getUserId()
                result.success(userId)
            }
            "setUserProperties" -> {
                val properties = call.arguments as Map<String, String>
                this.manager.setUserProperties(properties)
                result.success("ok")
            }
            "getUserProperties" -> {
                val properties = this.manager.getUserProperties()
                result.success(properties)
            }
            "connectEmbedding" -> {
                val channelId = call.argument<String>("channelId") as String
                val id = call.argument<String>("id") as String
                this.manager.connectEmbedding(channelId, id)
                result.success("ok")
            }
            "disconnectEmbedding" -> {
                val channelId = call.arguments as String
                this.manager.disconnectEmbedding(channelId)
                result.success("ok")
            }
            "connectRemoteConfig" -> {
                val channelId = call.argument<String>("channelId") as String
                val id = call.argument<String>("id") as String
                GlobalScope.launch(Dispatchers.IO) {
                    manager.connectRemoteConfig(channelId, id).onSuccess {
                        result.success(it)
                    }.onFailure {
                        result.success("failed")
                    }
                }
            }
            "disconnectRemoteConfig" -> {
                val channelId = call.arguments as String
                this.manager.disconnectRemoteConfig(channelId)
                result.success("ok")
            }
            "getRemoteConfigValue" -> {
                val channelId = call.argument<String>("channelId") as String
                val key = call.argument<String>("key") as String
                val value = this.manager.getRemoteConfigValue(channelId, key)
                result.success(value)
            }
            "connectEmbeddingInRemoteConfigValue" -> {
                val channelId = call.argument<String>("channelId") as String
                val embeddingChannelId = call.argument<String>("embeddingChannelId") as String
                val key = call.argument<String>("key") as String
                this.manager.connectEmbeddingInRemoteConfigValue(channelId, key, embeddingChannelId)
                result.success("ok")
            }

            // tooltip
            "connectTooltip" -> {
                val name = call.arguments as String
                GlobalScope.launch {
                    manager.connectTooltip(name = name).onSuccess {
                        result.success(it)
                    }.onFailure {
                        result.success("error: ${it.message}")
                    }
                }
            }
            "connectTooltipEmbedding" -> {
                val channelId = call.argument<String>("channelId") as String
                val rootBlock = call.argument<String>("json") as String
                this.manager.connectTooltipEmbedding(channelId, rootBlock)
                result.success("ok")
            }
            "callTooltipEmbeddingDispatch" -> {
                val channelId = call.argument<String>("channelId") as String
                val event = call.argument<String>("event") as String
                GlobalScope.launch(Dispatchers.IO) {
                    manager.callTooltipEmbeddingDispatch(channelId, event)
                    result.success("ok")
                }
            }
            "disconnectTooltipEmbedding" -> {
                val channelId = call.arguments as String
                this.manager.disconnectTooltip(channelId)
            }

            "dispatch" -> {
                val event = call.arguments as String
                this.manager.dispatch(event)
                result.success("ok")
            }
            "recordCrash" -> {
                try {
                    val errorData = call.arguments as Map<*, *>
                    val exception = errorData["exception"] as String
                    val stackTrace = errorData["stack"] as String

                    // Create a throwable with the Flutter error information
                    val throwable = Throwable(exception).apply {
                        this.stackTrace = parseStackTraceElements(stackTrace)
                    }

                    // Record the crash using the Nativebrik SDK
                    this.manager.recordCrash(throwable)
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("CRASH_REPORT_ERROR", "Failed to record crash: ${e.message}", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

// Helper method to parse Flutter stack trace into Java stack trace elements
//
// Flutter Stack Trace
// #0      NativebrikDispatcher.dispatch (package:nativebrik_bridge/dispatcher.dart:10:5)
// #1      _MyAppState.build.<anonymous closure> (package:nativebrik_bridge_example/main.dart:91:42)
// ....
//
// Kotlin.StackTraceElement
// StackTraceElement("NativebrikDispatcher", "dispatch", "package:nativebrik_bridge/dispatcher.dart", 10)
// ...
fun parseStackTraceElements(stackTraceString: String): Array<StackTraceElement> {
    val lines = stackTraceString.split("\n")
    return lines.mapNotNull { line ->
        try {
            // Simple parsing of Flutter stack trace format
            // This is a basic implementation and might need to be enhanced
            val trimmed = line.trim()
            if (trimmed.isEmpty()) return@mapNotNull null

            // Try to extract file, class, method and line information
            val parts = trimmed.split(" ")
            var fileInfo = parts.lastOrNull() ?: return@mapNotNull null
            // this cannot handle generics methods if the generics is <anonymous closure>.
            val methodPart = parts.takeLast(2).firstOrNull() ?: "unknown.unknown"

            // Default values
            var className = "unknown"
            var methodName = "unknown"
            var fileName = "unknown"
            var lineNumber = -1

            // Try to parse file and line information
            if (fileInfo.contains(":")) {
                fileInfo = fileInfo.substringAfter("(").substringBeforeLast(")")
                val fileParts = fileInfo.split(":").map { it.trim() }
                val packageName = fileParts.getOrNull(0) ?: "unknown"
                val flutterFileName = fileParts.getOrNull(1) ?: "unknown"
                fileName = "$packageName:$flutterFileName"
                lineNumber = fileParts.getOrNull(2)?.toIntOrNull() ?: -1
            }

            // Try to extract method name if available
            methodPart.let {
                val lastDot = methodPart.indexOf(".")
                if (lastDot > 0) {
                    className = methodPart.substring(0, lastDot)
                    methodName = methodPart.substring(lastDot + 1)
                }
            }

            StackTraceElement(className, methodName, fileName, lineNumber)
        } catch (e: Exception) {
            // If parsing fails, create a generic stack trace element
            StackTraceElement("flutter.Error", "unparseable", "flutter", -1)
        }
    }.toTypedArray()
}