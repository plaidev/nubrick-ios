package com.nativebrik.sdk.data

import com.nativebrik.sdk.Config
import com.nativebrik.sdk.data.user.formatISO8601
import com.nativebrik.sdk.data.user.getCurrentDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okio.withLock
import java.time.ZonedDateTime
import java.util.Timer
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.fixedRateTimer

data class TrackUserEvent(
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

data class TrackExperimentEvent(
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

sealed class TrackEvent {
    class UserEvent(val event: TrackUserEvent) : TrackEvent()
    class ExperimentEvent(val event: TrackExperimentEvent) : TrackEvent()

    fun encode(): JsonObject {
        return when (this) {
            is UserEvent -> this.event.encode()
            is ExperimentEvent -> this.event.encode()
        }
    }
}

interface TrackRepository {
    fun trackExperimentEvent(event: TrackExperimentEvent)
    fun trackEvent(event: TrackUserEvent)
}

class TrackRepositoryImpl: TrackRepository {
    private val queueLock: ReentrantLock = ReentrantLock()
    private val config: Config
    private var timer: Timer? = null
    private val maxBatchSize: Int = 50
    private val maxQueueSize: Int = 300
    private var buffer: MutableList<TrackEvent> = mutableListOf()

    internal constructor(config: Config) {
        this.config = config
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
                GlobalScope.launch(Dispatchers.Main) {
                    self.timer?.cancel()
                    self.timer = fixedRateTimer(initialDelay = 0, period = 4000) {
                        GlobalScope.launch(Dispatchers.IO) {
                            self.sendAndFlush()
                        }
                    }
                }
            }
            if (this.buffer.size >= this.maxBatchSize) {
                val self = this
                GlobalScope.launch(Dispatchers.IO) {
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
        val encodes = tempBuffer.map { it.encode() }
        val jsonArray = JsonArray(content = encodes)
        val body = Json.encodeToString(jsonArray)
        this.timer?.cancel()
        this.timer = null
        postRequest(this.config.endpoint.track, body).onFailure {
            this.buffer.addAll(tempBuffer)
        }
    }
}
