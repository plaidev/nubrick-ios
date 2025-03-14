package com.nativebrik.sdk.data

import com.nativebrik.sdk.CachePolicy
import com.nativebrik.sdk.data.user.getCurrentDate
import java.time.ZonedDateTime
import java.util.concurrent.locks.ReentrantReadWriteLock

internal class CacheStore(
    private val policy: CachePolicy
) {
    private val lock = ReentrantReadWriteLock()
    private val cache = mutableMapOf<String, CacheObject>()

    fun get(key: String): Result<CacheObject> {
        lock.readLock().lock()
        try {
            val cached = cache[key] ?: return Result.failure(NotFoundException())

            val now = getCurrentDate()
            val diff = now.toEpochSecond() - cached.timestamp.toEpochSecond()
            if (diff > policy.cacheTime.inWholeSeconds) { // if it's invalid
                cache.remove(key)
                return Result.failure(NotFoundException())
            }
            return Result.success(cached)
        } finally {
            lock.readLock().unlock()
        }
    }

    fun set(key: String, value: String): Result<Unit> {
        lock.writeLock().lock()
        try {
            val now = getCurrentDate()
            val cache = CacheObject(
                data = value,
            timestamp = now,
            policy = this.policy,
            )
            this.cache[key] = cache
            return Result.success(Unit)
        } finally {
            lock.writeLock().unlock()
        }
    }

    fun invalidate(key: String): Result<Unit> {
        lock.writeLock().lock()
        try {
            cache.remove(key)
            return Result.success(Unit)
        } finally {
            lock.writeLock().unlock()
        }
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