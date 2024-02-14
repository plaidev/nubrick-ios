package com.nativebrik.sdk.data.user

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import com.nativebrik.sdk.schema.BuiltinUserProperty
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID
import kotlin.random.Random


fun getNativebrikUserSharedPreferences(context: Context): SharedPreferences? {
    return context.getSharedPreferences(
        context.packageName + ".nativebrik.com.user",
        Context.MODE_PRIVATE
    )
}

internal fun getCurrentDate(): ZonedDateTime {
    return ZonedDateTime.now()
}

internal fun formatISO8601(time: ZonedDateTime): String {
    return time.format(DateTimeFormatter.ISO_INSTANT)
}

enum class UserPropertyType {
    INTEGER,
    STRING,
    TIMESTAMPZ,
    SEMVER,
    UNKNOWN,;
}

data class UserProperty(
    val name: String,
    val value: String,
    val type: UserPropertyType,
) {}

class NativebrikUser {
    private var properties: MutableMap<String, String> = mutableMapOf()
    private var preferences: SharedPreferences? = null
    private var lastBootTime: ZonedDateTime = getCurrentDate()

    var id: String = ""
        get() {
            return this.properties[BuiltinUserProperty.userId.toString()] ?: ""
        }

    constructor(context: Context) {
        this.preferences = getNativebrikUserSharedPreferences(context)

        // userId := uuid by default
        val userIdKey = BuiltinUserProperty.userId.toString()
        val userId: String = this.preferences?.getString(userIdKey, null) ?: UUID.randomUUID().toString()
        this.preferences?.edit()?.putString(userIdKey, userId)?.apply()
        this.properties[userIdKey] = userId

        // userRnd := n in [0,100)
        val userRndKey = BuiltinUserProperty.userRnd.toString()
        val userRnd: Int = this.preferences?.getInt(userRndKey, Random.nextInt(0, 100)) ?: Random.nextInt(0, 100)
        this.preferences?.edit()?.putInt(userRndKey, userRnd)?.apply()
        this.properties[userRndKey] = userRnd.toString()

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

        try {
            val sdkVersion = context.packageManager.getPackageInfo("com.nativebrik.sdk", 0).versionName
            this.properties[BuiltinUserProperty.sdkVersion.toString()] = sdkVersion
        } catch (_: Exception) {
            this.properties[BuiltinUserProperty.sdkVersion.toString()] = "0.0.0"
        }

        this.properties[BuiltinUserProperty.osName.toString()] = "Android"
        this.properties[BuiltinUserProperty.osVersion.toString()] = Build.VERSION.SDK_INT.toString()


        try {
            val packageName = context.packageName
            val appVersion = context.packageManager.getPackageInfo(packageName, 0).versionName
            this.properties[BuiltinUserProperty.appVersion.toString()] = appVersion
        } catch (_: Exception) {
            this.properties[BuiltinUserProperty.appVersion.toString()] = "0.0.0"
        }

        this.comeBack()
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

    fun getUserRnd(seed: Int?): Int {
        val rndStr = this.properties[BuiltinUserProperty.userRnd.toString()] ?: "0"
        val rnd = rndStr.toIntOrNull() ?: 0
        val seededRand = Random(seed ?: 0).nextDouble() * 100.0
        return (rnd + seededRand.toInt()) % 100
    }

    fun getNormalizedUserRnd(seed: Int?): Double {
        return this.getUserRnd(seed).toDouble() / 100.0
    }

    fun toUserProperties(seed: Int? = 0): List<UserProperty> {
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
                val prop = UserProperty(
                    name = key,
                    value = this.getUserRnd(seed = seed).toString(),
                    type = UserPropertyType.INTEGER
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