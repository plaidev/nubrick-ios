package com.nativebrik.sdk.data

import com.nativebrik.sdk.CachePolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.ZonedDateTime
import kotlin.time.Duration.Companion.seconds

class CacheStoreTest {
    private lateinit var cacheStore: CacheStore
    private val defaultPolicy = CachePolicy(
        cacheTime = 60.seconds,
        staleTime = 30.seconds
    )
    private var currentTime: ZonedDateTime = ZonedDateTime.now()

    @Before
    fun setup() {
        currentTime = ZonedDateTime.now()
        // Override getCurrentDate for testing
        com.nativebrik.sdk.data.user.DATETIME_OFFSET = 0
        cacheStore = CacheStore(defaultPolicy)
    }

    @Test
    fun `test basic set and get operations`() {
        // Given
        val key = "test-key"
        val value = "test-value"

        // When
        val setResult = cacheStore.set(key, value)
        val getResult = cacheStore.get(key)

        // Then
        assertTrue(setResult.isSuccess)
        assertTrue(getResult.isSuccess)
        assertEquals(value, getResult.getOrNull()?.data)
    }

    @Test
    fun `test get non-existent key returns failure`() {
        // When
        val result = cacheStore.get("non-existent-key")

        // Then
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is NotFoundException)
    }

    @Test
    fun `test cache invalidation`() {
        // Given
        val key = "test-key"
        val value = "test-value"
        cacheStore.set(key, value)

        // When
        val invalidateResult = cacheStore.invalidate(key)
        val getResult = cacheStore.get(key)

        // Then
        assertTrue(invalidateResult.isSuccess)
        assertTrue(getResult.isFailure)
        assertTrue(getResult.exceptionOrNull() is NotFoundException)
    }

    @Test
    fun `test cache object staleness`() {
        // Given
        val now = ZonedDateTime.now()
        val staleTimestamp = now.minusSeconds(35) // Past stale time (30s)
        val cacheObject = CacheObject(
            data = "test-data",
            timestamp = staleTimestamp,
            policy = defaultPolicy
        )

        // Then
        assertTrue(cacheObject.isStale())
    }

    @Test
    fun `test cache object freshness`() {
        // Given
        val now = ZonedDateTime.now()
        val freshTimestamp = now.minusSeconds(15) // Within stale time (30s)
        val cacheObject = CacheObject(
            data = "test-data",
            timestamp = freshTimestamp,
            policy = defaultPolicy
        )

        // Then
        assertFalse(cacheObject.isStale())
    }

    @Test
    fun `test expired cache returns failure`() {
        // Given
        val key = "test-key"
        val value = "test-value"
        val shortPolicy = CachePolicy(
            cacheTime = 1.seconds,
            staleTime = 1.seconds
        )
        cacheStore = CacheStore(shortPolicy)

        // When
        val setResult = cacheStore.set(key, value)
        assertTrue("Set operation should succeed", setResult.isSuccess)

        // Simulate time passing by adjusting the time offset
        com.nativebrik.sdk.data.user.DATETIME_OFFSET = 2000 // 2 seconds in milliseconds

        val getResult = cacheStore.get(key)

        // Then
        assertTrue("Cache should be expired", getResult.isFailure)
        assertTrue("Should throw NotFoundException", getResult.exceptionOrNull() is NotFoundException)
    }
}