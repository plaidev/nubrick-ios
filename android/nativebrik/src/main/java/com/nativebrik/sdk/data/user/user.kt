package com.nativebrik.sdk.data.user

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import com.nativebrik.sdk.VERSION
import com.nativebrik.sdk.schema.BuiltinUserProperty
import java.net.HttpURLConnection
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.random.Random

internal fun getNativebrikUserSharedPreferences(context: Context): SharedPreferences? {
    return context.getSharedPreferences(
        context.packageName + ".nativebrik.com.user",
        Context.MODE_PRIVATE
    )
}

internal const val USER_SEED_MAX = 100000000
internal const val USER_SEED_KEY = "NATIVEBRIK_USER_SEED"

internal var DATETIME_OFFSET: Long = 0
internal fun getCurrentDate(): ZonedDateTime {
    val currentMillis = ZonedDateTime.now().toInstant().toEpochMilli()
    return ZonedDateTime.ofInstant(
        Instant.ofEpochMilli(currentMillis + DATETIME_OFFSET),
        ZoneId.systemDefault()
    )
}

internal fun syncDateFromHttpResponse(t0: Long, connection: HttpURLConnection) {
    val t1 = System.currentTimeMillis()

    val serverDateStr = connection.headerFields["Date"]?.firstOrNull() ?: return

    val serverTime = try {
        val formatter = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("GMT")
        formatter.parse(serverDateStr)?.time ?: return
    } catch (e: Exception) {
        return
    }

    val networkDelay = (t1 - t0) / 2
    val estimatedServerTime = serverTime + networkDelay

    DATETIME_OFFSET = estimatedServerTime - t1
}

internal fun getToday(): ZonedDateTime {
    val now = getCurrentDate()
    return now.truncatedTo(ChronoUnit.DAYS)
}

internal fun formatISO8601(time: ZonedDateTime): String {
    return time.format(DateTimeFormatter.ISO_INSTANT)
}

internal enum class UserPropertyType {
    INTEGER,
    DOUBLE,
    STRING,
    TIMESTAMPZ,
    SEMVER,
}

internal data class UserProperty(
    val name: String,
    val value: String,
    val type: UserPropertyType,
)

class NativebrikUser {
    private var properties: MutableMap<String, String> = mutableMapOf()
    internal var preferences: SharedPreferences? = null
    private var lastBootTime: ZonedDateTime = getCurrentDate()
    internal var packageName: String? = null
    internal var appVersion: String? = null

    val id: String
        get() {
            return this.properties[BuiltinUserProperty.userId.toString()] ?: ""
        }

    val retention: Int
        get() {
            return (this.properties[BuiltinUserProperty.retentionPeriod.toString()] ?: "0").toInt()
        }

    internal constructor(context: Context, seed: Int? = null) {
        this.preferences = getNativebrikUserSharedPreferences(context)

        // userId := uuid by default
        val userIdKey = BuiltinUserProperty.userId.toString()
        val userId: String = this.preferences?.getString(userIdKey, null) ?: UUID.randomUUID().toString()
        this.preferences?.edit()?.putString(userIdKey, userId)?.apply()
        this.properties[userIdKey] = userId

        // USER_SEED_KEY := n in [0,USER_SEED_MAX)
        val rand = if (seed != null) Random(seed) else Random
        val userSeed: Int = this.preferences?.getInt(USER_SEED_KEY, rand.nextInt(0, USER_SEED_MAX)) ?: rand.nextInt(0, USER_SEED_MAX)
        this.preferences?.edit()?.putInt(USER_SEED_KEY, userSeed)?.apply()
        this.properties[USER_SEED_KEY] = userSeed.toString()

        val languageCode = Locale.getDefault().toLanguageTag()
        this.properties[BuiltinUserProperty.languageCode.toString()] = languageCode

        val regionCode = Locale.getDefault().country.toString()
        this.properties[BuiltinUserProperty.regionCode.toString()] = regionCode

        val firstBootTimeKey = BuiltinUserProperty.firstBootTime.toString()
        val firstBootTime: String = this.preferences?.getString(firstBootTimeKey, null) ?: formatISO8601(
            getCurrentDate()
        )
        this.preferences?.edit()?.putString(firstBootTimeKey, firstBootTime)?.apply()
        this.properties[firstBootTimeKey] = firstBootTime

        this.properties[BuiltinUserProperty.sdkVersion.toString()] = VERSION

        this.properties[BuiltinUserProperty.osName.toString()] = "Android"
        this.properties[BuiltinUserProperty.osVersion.toString()] = Build.VERSION.SDK_INT.toString()

        try {
            val packageName = context.packageName
            this.packageName = packageName
            this.properties[BuiltinUserProperty.appId.toString()] = packageName
            val appVersion = context.packageManager.getPackageInfo(packageName, 0).versionName
            this.properties[BuiltinUserProperty.appVersion.toString()] = appVersion
            this.appVersion = appVersion
        } catch (_: Exception) {
            this.properties[BuiltinUserProperty.appVersion.toString()] = "0.0.0"
        }

        this.comeBack()
    }

    fun set(props: Map<String, String>) {
        props.forEach { (key, value) ->
            this.properties[key] = value
        }
    }

    fun comeBack() {
        val now = getCurrentDate()
        val lastBootTime = getCurrentDate()
        this.properties[BuiltinUserProperty.lastBootTime.toString()] = formatISO8601(lastBootTime)
        this.lastBootTime = lastBootTime

        val retentionPeriodKey = BuiltinUserProperty.retentionPeriod.toString()
        val retentionTimestamp = this.preferences?.getLong(retentionPeriodKey, now.toEpochSecond()) ?: now.toEpochSecond()
        var retentionPeriodCountKey = "retentionPeriodCount"
        val retentionCount = this.preferences?.getInt(retentionPeriodCountKey, 0) ?: 0
        this.properties[retentionPeriodKey] = retentionCount.toString()

        // 1 day is equal to 86400 seconds
        val lastDaysSince0 = retentionTimestamp / (86400)
        val daysSince0 = now.toEpochSecond() / (86400)
        if (lastDaysSince0 == daysSince0 - 1) {
            // count up retention. because user is returned in 1 day
            val countedUp = retentionCount + 1
            this.preferences?.edit()
                ?.putLong(retentionPeriodKey, now.toEpochSecond())
                ?.putInt(retentionPeriodCountKey, countedUp)
                ?.apply()
            this.properties[retentionPeriodKey] = countedUp.toString()
        } else if (lastDaysSince0 == daysSince0) {
            // save the initial count
            this.preferences?.edit()
                ?.putLong(retentionPeriodKey, retentionTimestamp)
                ?.putInt(retentionPeriodCountKey, retentionCount)
                ?.apply()
        } else if (lastDaysSince0 < daysSince0 - 1) {
            // reset retention. because user won't be returned in 1 day
            val reset = 0
            this.preferences?.edit()
                ?.putLong(retentionPeriodKey, now.toEpochSecond())
                ?.putInt(retentionPeriodCountKey, reset)
                ?.apply()
            this.properties[retentionPeriodKey] = reset.toString()
        }
    }

    // n in [0,1)
    internal fun getNormalizedUserRnd(seed: Int?): Double {
        val userSeedStr: String = this.properties[USER_SEED_KEY] ?: "0"
        val userSeed: Int = userSeedStr.toIntOrNull() ?: 0
        return Random((seed ?: 0) + userSeed).nextDouble()
    }

    internal fun toUserProperties(seed: Int? = 0): List<UserProperty> {
        val now = getCurrentDate()
        val props: MutableList<UserProperty> = mutableListOf()

        val bootingTime = now.toEpochSecond() - this.lastBootTime.toEpochSecond()
        props.addAll(listOf(
            UserProperty(
                name = BuiltinUserProperty.currentTime.toString(),
                value = formatISO8601(now),
                type = UserPropertyType.TIMESTAMPZ,
            ),
            UserProperty(
                name = BuiltinUserProperty.bootingTime.toString(),
                value = bootingTime.toString(),
                type = UserPropertyType.INTEGER
            )
        ))

        props.addAll(listOf(
            UserProperty(
                name = BuiltinUserProperty.localYear.toString(),
                value = now.year.toString(),
                type = UserPropertyType.INTEGER,
            ),
            UserProperty(
                name = BuiltinUserProperty.localMonth.toString(),
                value = now.month.value.toString(),
                type = UserPropertyType.INTEGER
            ),
            UserProperty(
                name = BuiltinUserProperty.localDay.toString(),
                value = now.dayOfMonth.toString(),
                type = UserPropertyType.INTEGER,
            ),
            UserProperty(
                name = BuiltinUserProperty.localHour.toString(),
                value = now.hour.toString(),
                type = UserPropertyType.INTEGER,
            ),
            UserProperty(
                name = BuiltinUserProperty.localMinute.toString(),
                value = now.minute.toString(),
                type = UserPropertyType.INTEGER,
            ),
            UserProperty(
                name = BuiltinUserProperty.localSecond.toString(),
                value = now.second.toString(),
                type = UserPropertyType.INTEGER,
            ),
            UserProperty(
                name = BuiltinUserProperty.localWeekday.toString(),
                value = now.dayOfWeek.toString(),
                type = UserPropertyType.STRING,
            )
        ))

        this.properties.forEach { (key, value) ->
            if (key == BuiltinUserProperty.userRnd.toString()) {
                // not to use userRnd prop. use USER_SEED_KEY instead.
                return@forEach
            } else if (key == USER_SEED_KEY) {
                // add userRnd when it's USER_SEED_KEY
                val prop = UserProperty(
                    name = BuiltinUserProperty.userRnd.toString(),
                    value = this.getNormalizedUserRnd(seed = seed).toString(),
                    type = UserPropertyType.DOUBLE
                )
                props.add(prop)
            } else {
                props.add(UserProperty(
                    name = key,
                    value = value,
                    type = when (key) {
                        BuiltinUserProperty.userId.toString() -> UserPropertyType.STRING
                        BuiltinUserProperty.firstBootTime.toString() -> UserPropertyType.TIMESTAMPZ
                        BuiltinUserProperty.lastBootTime.toString() -> UserPropertyType.TIMESTAMPZ
                        BuiltinUserProperty.retentionPeriod.toString() -> UserPropertyType.INTEGER
                        BuiltinUserProperty.osName.toString() -> UserPropertyType.STRING
                        BuiltinUserProperty.osVersion.toString() -> UserPropertyType.SEMVER
                        BuiltinUserProperty.sdkVersion.toString() -> UserPropertyType.SEMVER
                        BuiltinUserProperty.appVersion.toString() -> UserPropertyType.SEMVER
                        else -> UserPropertyType.STRING
                    }
                ))
            }
        }

        return props
    }
}