package com.nativebrik.sdk.data.user

import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import java.net.HttpURLConnection
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

class UtilsUnitTest {
    @Test
    fun testSyncDateFromHttpResponse_shouldWork() {
        com.nativebrik.sdk.data.user.DATETIME_OFFSET = 0
        val now = System.currentTimeMillis()
        val tomorrow = Date(now + (24 * 60 * 60 * 1000))
        val formatter = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("GMT")
        }
        val formattedDate = formatter.format(tomorrow)
        val connection = mock(HttpURLConnection::class.java)
            `when`(connection.responseCode).thenReturn(400)
            `when`(connection.getHeaderField("Date")).thenReturn(formattedDate)

        syncDateFromHttpResponse(now, connection)
        val offset = com.nativebrik.sdk.data.user.DATETIME_OFFSET
        val diff = abs(offset - 24 * 60 * 60 * 1000)

        assertTrue("time offset should be around 24 hours", diff < 1000)
    }

    @Test
    fun testGetCurrentDate() {
        com.nativebrik.sdk.data.user.DATETIME_OFFSET = 24 * 60 * 60 * 1000
        val deviceCurrent = System.currentTimeMillis()
        val syncedCurrent = getCurrentDate().toInstant().toEpochMilli()
        val diff = (syncedCurrent - deviceCurrent) / 1000

        assertTrue("(diff - 24 hours) should be around 2 sec", abs(diff - 24 * 60 * 60) < 2)
    }
}