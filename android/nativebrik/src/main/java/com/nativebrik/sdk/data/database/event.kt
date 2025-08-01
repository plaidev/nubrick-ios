package com.nativebrik.sdk.data.database

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.provider.BaseColumns
import com.nativebrik.sdk.data.user.formatISO8601
import com.nativebrik.sdk.data.user.getCurrentDate
import com.nativebrik.sdk.schema.DateTime
import com.nativebrik.sdk.schema.FrequencyUnit
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

private object UserEventTable {
    const val Name: String = "event"
    object Columns: BaseColumns {
        const val Name = "name"
        const val Timestamp = "timestamp"
    }
}

internal const val SQL_CREATE_USER_EVENT_TABLE = """
    CREATE TABLE ${UserEventTable.Name} (
        ${BaseColumns._ID} INTEGER PRIMARY KEY,
        ${UserEventTable.Columns.Name} TEXT,
        ${UserEventTable.Columns.Timestamp} DATETIME
    )
"""

internal class UserEvent(private val db: SQLiteDatabase) {
    fun append(
        name: String
    ): Long {
        val values = ContentValues().apply {
            put(UserEventTable.Columns.Name, name)
            put(UserEventTable.Columns.Timestamp, formatISO8601(getCurrentDate()))
        }
        return db.insert(UserEventTable.Name, null, values)
    }

    fun existAfter(name: String, after: ZonedDateTime): Boolean {
        val cursor = this.db.query(
            UserEventTable.Name,
            arrayOf(BaseColumns._ID),
            "${UserEventTable.Columns.Name} = ? AND ${UserEventTable.Columns.Timestamp} > ?",
            arrayOf(name, formatISO8601(after)),
            null,
            null,
            null,
            "1"
        )
        var result: Boolean
        with(cursor) {
            result = moveToNext()
        }
        cursor.close()
        return result
    }

    /**
     * Calculate the number of events aggregated by the given [unit].
     * The result is a map whose key is the bucket start ([ZonedDateTime]) and value is the
     * number of events that fall into that bucket.
     *
     * @param name           Event name to aggregate.
     * @param unit           Time unit used as aggregation bucket.
     * @param lookbackPeriod Number of [unit]s to look back **from the `since` date**. If null, defaults to 50 years.
     * @param since          ISO-8601 timestamp string that defines the upper-bound (latest) date to look back from.
     *                       If null, defaults to 50 years ago.
     */
    fun counts(
        name: String,
        unit: FrequencyUnit,
        lookbackPeriod: Int?,
        since: DateTime?
    ): Map<ZonedDateTime, Int> {
        // House-keeping: delete very old records (> 4 years)
        val deleteSelection = "${UserEventTable.Columns.Timestamp} < ?"
        val deleteSelectionArgs = arrayOf(formatISO8601(getCurrentDate().minusDays((365 * 4).toLong())))
        db.delete(UserEventTable.Name, deleteSelection, deleteSelectionArgs)

        // Determine reference dates
        val fiftyYearsDays = 365 * 50
        val today = getCurrentDate()
        val sinceDate: ZonedDateTime = since ?: today.minusDays(fiftyYearsDays.toLong())
        val period = lookbackPeriod ?: fiftyYearsDays
        val startDate = unit.subtract(period, today)
        val lowerBound = if (startDate.isAfter(sinceDate)) startDate else sinceDate

        // Fetch timestamps from DB after the lowerBound
        val timestamps = fetchTimestampsAfter(name, lowerBound)

        // Aggregate counts per bucket
        val counts: MutableMap<ZonedDateTime, Int> = mutableMapOf()
        for (ts in timestamps) {
            val bucket = unit.bucketStart(ts)
            counts[bucket] = counts.getOrDefault(bucket, 0) + 1
        }
        return counts
    }

    /**
     * Fetch timestamps of events whose name matches and occurred after [after].
     * Returned timestamps are converted to UTC ZonedDateTime.
     */
    private fun fetchTimestampsAfter(name: String, after: ZonedDateTime): List<ZonedDateTime> {
        val cursor = this.db.query(
            UserEventTable.Name,
            arrayOf(UserEventTable.Columns.Timestamp),
            "${UserEventTable.Columns.Name} = ? AND ${UserEventTable.Columns.Timestamp} >= ?",
            arrayOf(name, formatISO8601(after)),
            null,
            null,
            null,
        )

        val timeIdx = cursor.getColumnIndexOrThrow(UserEventTable.Columns.Timestamp)
        val list = mutableListOf<ZonedDateTime>()
        while (cursor.moveToNext()) {
            val tsStr = cursor.getString(timeIdx) ?: continue
            try {
                val instant = Instant.parse(tsStr)
                list.add(instant.atZone(ZoneOffset.UTC))
            } catch (_: Exception) {
            }
        }
        cursor.close()
        return list
    }
}

// -----------------------------------------------------------------------------
// FrequencyUnit helpers – implemented as extension functions to avoid polluting
// the original enum definition generated elsewhere.
// -----------------------------------------------------------------------------

internal fun FrequencyUnit.subtract(value: Int, from: ZonedDateTime): ZonedDateTime = when (this) {
    FrequencyUnit.MINUTE -> from.minusMinutes(value.toLong())
    FrequencyUnit.HOUR -> from.minusHours(value.toLong())
    FrequencyUnit.DAY -> from.minusDays(value.toLong())
    FrequencyUnit.WEEK -> from.minusWeeks(value.toLong())
    FrequencyUnit.MONTH -> from.minusMonths(value.toLong())
    else -> from.minusDays(value.toLong())
}

internal fun FrequencyUnit.bucketStart(date: ZonedDateTime): ZonedDateTime = when (this) {
    FrequencyUnit.MINUTE -> date.truncatedTo(ChronoUnit.MINUTES)
    FrequencyUnit.HOUR -> date.truncatedTo(ChronoUnit.HOURS)
    FrequencyUnit.DAY -> date.truncatedTo(ChronoUnit.DAYS)
    FrequencyUnit.WEEK -> date.with(DayOfWeek.MONDAY).truncatedTo(ChronoUnit.DAYS)
    FrequencyUnit.MONTH -> date.withDayOfMonth(1).truncatedTo(ChronoUnit.DAYS)
    else -> date.truncatedTo(ChronoUnit.DAYS)
}
