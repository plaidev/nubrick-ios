package com.nativebrik.sdk.data.database

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.provider.BaseColumns
import com.nativebrik.sdk.data.user.formatISO8601
import com.nativebrik.sdk.data.user.getCurrentDate
import java.time.ZonedDateTime

private object ExperimentHistoryTable {
    const val Name: String = "experiment_history"
    object Columns: BaseColumns {
        const val ExperimentId = "experiment_id"
        const val Timestamp = "timestamp"
    }
}

internal const val SQL_CREATE_EXPERIMENT_HISTORY_TABLE = """
    CREATE TABLE ${ExperimentHistoryTable.Name} (
        ${BaseColumns._ID} INTEGER PRIMARY KEY,
        ${ExperimentHistoryTable.Columns.ExperimentId} TEXT,
        ${ExperimentHistoryTable.Columns.Timestamp} DATETIME
    )
"""

internal class ExperimentHistory(private val db: SQLiteDatabase) {
    fun append(
        experimentId: String
    ): Long {
        val values = ContentValues().apply {
            put(ExperimentHistoryTable.Columns.ExperimentId, experimentId)
            put(ExperimentHistoryTable.Columns.Timestamp, formatISO8601(getCurrentDate()))
        }
        return db.insert(ExperimentHistoryTable.Name, null, values)
    }

    fun countAfter(
        experimentId: String,
        after: ZonedDateTime
    ): Long {
        val sortOrder = "${ExperimentHistoryTable.Columns.Timestamp} DESC"
        val deleteSelection = "${ExperimentHistoryTable.Columns.Timestamp} < ?"
        val deleteSelectionArgs = arrayOf(formatISO8601(getCurrentDate().minusDays(365 * 4)))
        this.db.delete(ExperimentHistoryTable.Name, deleteSelection, deleteSelectionArgs)

        val projection = arrayOf("count(${ExperimentHistoryTable.Columns.Timestamp}) as count",)
        val selection = """
            ${ExperimentHistoryTable.Columns.ExperimentId} = ?
            AND
            ${ExperimentHistoryTable.Columns.Timestamp} > ?
        """.trimIndent()
        val selectionArgs = arrayOf(
            experimentId,
            formatISO8601(after),
        )
        val cursor = this.db.query(
            ExperimentHistoryTable.Name,
            projection,
            selection,
            selectionArgs,
            null,
            null,
            sortOrder
        )
        var count: Long = 0
        with(cursor) {
            if (moveToNext()) {
                try {
                    count = getLong(getColumnIndexOrThrow("count"))
                } catch (_: Exception) {}
            }
        }
        cursor.close()
        return count
    }
}
