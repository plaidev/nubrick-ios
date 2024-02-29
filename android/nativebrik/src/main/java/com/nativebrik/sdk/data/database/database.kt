package com.nativebrik.sdk.data.database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.nativebrik.sdk.data.user.getToday
import com.nativebrik.sdk.schema.ExperimentFrequency

internal interface DatabaseRepository {
    fun appendUserEvent(name: String)
    fun appendExperimentHistory(experimentId: String)
    fun isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?): Boolean
}

private const val DATABASE_NAME = "Nativebrik.sdk.db"
private const val DATABASE_VERSION = 1
internal class NativebrikDbHelper(context: Context): SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        try {
            db.execSQL(SQL_CREATE_EXPERIMENT_HISTORY_TABLE)
            db.execSQL(SQL_CREATE_USER_EVENT_TABLE)
        } catch (_: Exception) {
            throw Exception("Nativebrik SDK couldn't create a sqlite database.")
        }
    }

    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {}

    override fun onDowngrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {
        onUpgrade(db, oldVersion, newVersion)
    }
}

internal class DatabaseRepositoryImpl(private val db: SQLiteDatabase): DatabaseRepository {
    private val history = ExperimentHistory(this.db)
    private val userEvent = UserEvent(this.db)

    override fun appendUserEvent(name: String) {
        userEvent.append(name)
    }

    override fun appendExperimentHistory(experimentId: String) {
        history.append(experimentId)
    }

    override fun isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?): Boolean {
        if (frequency == null) return true
        val period = frequency.period ?: (365 * 50)
        val after = getToday().minusDays(period.toLong())
        val count = history.countAfter(experimentId, after)
        return count.toInt() == 0
    }
}