package com.nativebrik.sdk.data.database

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.provider.BaseColumns
import com.nativebrik.sdk.data.user.formatISO8601
import com.nativebrik.sdk.data.user.getCurrentDate
import java.time.ZonedDateTime

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
}