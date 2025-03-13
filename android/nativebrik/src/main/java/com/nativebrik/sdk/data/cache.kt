package com.nativebrik.sdk.data

import com.nativebrik.sdk.CachePolicy
import com.nativebrik.sdk.data.user.getCurrentDate
import java.time.ZonedDateTime

internal class Cache(
    private val policy: CachePolicy
) {
    private val cache = mutableMapOf<String, CacheObject>()

    fun get(key: String): Result<CacheObject> {
        val cached = cache[key] ?: return Result.failure(NotFoundException())

        val now = getCurrentDate()
        val diff = now.toEpochSecond() - cached.timestamp.toEpochSecond()
        if (diff > policy.cacheTime.inWholeSeconds) { // if it's invalid
            cache.remove(key)
            return Result.failure(NotFoundException())
        }
        return Result.success(cached)
    }

    fun set(key: String, value: String): Result<Unit> {
        val now = getCurrentDate()
        val cache = CacheObject(
            data = value,
            timestamp = now,
            policy = this.policy,
        )
        this.cache[key] = cache
        return Result.success(Unit)
    }

    fun invalidate(key: String): Result<Unit> {
        cache.remove(key)
        return Result.success(Unit)
    }
}

internal data class CacheObject(
    val data: String,
    internal val timestamp: ZonedDateTime,
    private val policy: CachePolicy
) {
    fun isStale(): Boolean {
        val now = getCurrentDate()
        val diff = now.toEpochSecond() - timestamp.toEpochSecond()
        return diff > policy.staleTime.inWholeSeconds
    }
}