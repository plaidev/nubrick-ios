package com.nativebrik.sdk.data

import com.nativebrik.sdk.Config
import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.data.user.formatISO8601
import com.nativebrik.sdk.data.user.getCurrentDate
import com.nativebrik.sdk.schema.ListDecoder
import com.nativebrik.sdk.schema.StringDecoder
import com.nativebrik.sdk.schema.TriggerEventNameDefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import okio.withLock
import java.time.ZonedDateTime
import java.util.Timer
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.fixedRateTimer

private val CRASH_RECORD_KEY = "CRASH_RECORD_KEY"

data class CrashRecord(
    val reason: String?,
    val callStacks: List<String>?
) {
    fun encode(): JsonObject {
        val callStacks = this.callStacks?.map {
            JsonPrimitive(it)
        } ?: emptyList()
        return JsonObject(mapOf(
            "reason" to JsonPrimitive(this.reason),
            "callStacks" to JsonArray(callStacks)
        ))
    }

    companion object {
        fun decode(element: JsonElement?): CrashRecord? {
            if (element == null) return null
            if (element !is JsonObject) return null

            return CrashRecord(
                reason = StringDecoder.decode(element.jsonObject["name"]),
                callStacks = ListDecoder.decode(element.jsonObject["callStacks"]) {
                    StringDecoder.decode(
                        it
                    )
                },
            )
        }
    }
}


internal data class TrackUserEvent(
    val name: String,
    val timestamp: ZonedDateTime = getCurrentDate(),
) {
    fun encode(): JsonObject {
        return JsonObject(mapOf(
            "typename" to JsonPrimitive("event"),
            "name" to JsonPrimitive(this.name),
            "timestamp" to JsonPrimitive(formatISO8601(this.timestamp)),
        ))
    }
}

internal data class TrackExperimentEvent(
    val experimentId: String,
    val variantId: String,
    val timestamp: ZonedDateTime = getCurrentDate(),
) {
    fun encode(): JsonObject {
        return JsonObject(mapOf(
            "typename" to JsonPrimitive("experiment"),
            "experimentId" to JsonPrimitive(this.experimentId),
            "variantId" to JsonPrimitive(this.variantId),
            "timestamp" to JsonPrimitive(formatISO8601(this.timestamp)),
        ))
    }
}

internal sealed class TrackEvent {
    class UserEvent(val event: TrackUserEvent) : TrackEvent()
    class ExperimentEvent(val event: TrackExperimentEvent) : TrackEvent()

    fun encode(): JsonObject {
        return when (this) {
            is UserEvent -> this.event.encode()
            is ExperimentEvent -> this.event.encode()
        }
    }
}

internal data class TrackRequest(
    val projectId: String,
    val userId: String,
    val events: List<TrackEvent>,
    val timestamp: ZonedDateTime = getCurrentDate(),
) {
    fun encode(): JsonObject {
        val events = this.events.map { it.encode() }
        return JsonObject(mapOf(
            "projectId" to JsonPrimitive(projectId),
            "userId" to JsonPrimitive(userId),
            "timestamp" to JsonPrimitive(formatISO8601(timestamp)),
            "events" to JsonArray(events)
        ))
    }
}

internal interface TrackRepository {
    fun trackExperimentEvent(event: TrackExperimentEvent)
    fun trackEvent(event: TrackUserEvent)

    fun record(throwable: Throwable)
}

internal class TrackRepositoryImpl: TrackRepository {
    private val queueLock: ReentrantLock = ReentrantLock()
    private val config: Config
    private val user: NativebrikUser
    private var timer: Timer? = null
    private val maxBatchSize: Int = 50
    private val maxQueueSize: Int = 300
    private var buffer: MutableList<TrackEvent> = mutableListOf()

    internal constructor(config: Config, user: NativebrikUser) {
        this.config = config
        this.user = user

        this.report()
    }

    override fun trackEvent(event: TrackUserEvent) {
        this.enqueue(TrackEvent.UserEvent(event))
    }

    override fun trackExperimentEvent(event: TrackExperimentEvent) {
        this.enqueue(TrackEvent.ExperimentEvent(event))
    }

    private fun enqueue(event: TrackEvent) {
        this.queueLock.withLock {
            if (this.timer == null) {
                val self = this
                CoroutineScope(Dispatchers.Main).launch {
                    self.timer?.cancel()
                    self.timer = fixedRateTimer(initialDelay = 0, period = 4000) {
                        CoroutineScope(Dispatchers.IO).launch {
                            self.sendAndFlush()
                        }
                    }
                }
            }
            if (this.buffer.size >= this.maxBatchSize) {
                val self = this
                CoroutineScope(Dispatchers.IO).launch {
                    self.sendAndFlush()
                }
            }
            this.buffer.add(event)
            if (buffer.size >= this.maxQueueSize) {
                this.buffer.drop(this.maxQueueSize - this.buffer.size)
            }
        }
    }

    private fun sendAndFlush() {
        val tempBuffer = this.buffer
        if (tempBuffer.isEmpty()) return
        this.buffer = mutableListOf()
        val request = TrackRequest(
            projectId = config.projectId,
            userId = user.id,
            events = tempBuffer
        )
        val body = Json.encodeToString(request.encode())
        this.timer?.cancel()
        this.timer = null
        postRequest(this.config.endpoint.track, body).onFailure {
            this.buffer.addAll(tempBuffer)
        }
    }

    private fun report() {
        val data = this.user.preferences?.getString(CRASH_RECORD_KEY, "") ?: ""
        if (data.isEmpty()) {
            return
        }
        this.user.preferences?.edit()?.remove(CRASH_RECORD_KEY)?.apply()

        val json = Json.decodeFromString<JsonElement>(data)
        val crashRecord = CrashRecord.decode(json) ?: return
        val causedByNativebrik = crashRecord.callStacks?.any { it.contains("com.nativebrik.sdk") } == true ||
                                 crashRecord.reason?.contains("com.nativebrik.sdk") == true

        this.buffer.add(TrackEvent.UserEvent(TrackUserEvent(
            name = TriggerEventNameDefs.N_ERROR_RECORD.name
        )))

        if (causedByNativebrik) {
            buffer.add(TrackEvent.UserEvent(TrackUserEvent(
                name = TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD.name
            )))
        }

        val self = this
        CoroutineScope(Dispatchers.IO).launch {
            self.sendAndFlush()
        }
    }

    override fun record(throwable: Throwable) {
        val record = CrashRecord(
            reason = throwable.message,
            callStacks = throwable.stackTrace.map { it.toString() }
        )
        val data = Json.encodeToString(record.encode())
        this.user.preferences?.edit()?.putString(CRASH_RECORD_KEY, data)?.apply()
    }
}
