package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.data.user.UserPropertyType
import com.nativebrik.sdk.schema.ConditionOperator
import java.time.ZonedDateTime
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException

internal fun comparePropWithConditionValue(prop: UserProperty, value: String, op: ConditionOperator): Boolean {
    val values = value.split(",")
    return when (prop.type) {
        UserPropertyType.INTEGER -> {
            val propValue = prop.value.trim().toIntOrNull() ?: 0
            val conditionValues = values.map { it.trim().toIntOrNull() ?: 0 }
            compareInteger(a = propValue, b = conditionValues, op = op)
        }
        UserPropertyType.DOUBLE -> {
            val propValue: Double = prop.value.trim().toDoubleOrNull() ?: 0.toDouble()
            val conditionValues = values.map { it.trim().toDoubleOrNull() ?: 0.toDouble() }
            compareDouble(a = propValue, b = conditionValues, op = op)
        }
        UserPropertyType.STRING -> {
            val strings = values.map { it }
            compareString(a = prop.value, b = strings, op = op)
        }
        UserPropertyType.SEMVER -> {
            val strings = values.map { it.trim() }
            compareSemver(a = prop.value, b = strings, op = op)
        }
        UserPropertyType.TIMESTAMPZ -> {
            try {
                val propValue =  ZonedDateTime.parse(prop.value.trim()).toInstant().toEpochMilli().div(1000)
                val conditionValues = values.map { ZonedDateTime.parse(it.trim()).toInstant().toEpochMilli().div(1000) }
                compareLong(a = propValue, b = conditionValues, op = op)
            } catch (e: Exception) {
                compareLong(a = 0, b = emptyList(), op = op)
            }
        }
        else -> false
    }
}

internal fun compareInteger(a: Int, b: List<Int>, op: ConditionOperator): Boolean {
    return when (op) {
        ConditionOperator.Equal -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
        ConditionOperator.NotEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a != b[0]
        }
        ConditionOperator.GreaterThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a > b[0]
        }
        ConditionOperator.GreaterThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a >= b[0]
        }
        ConditionOperator.LessThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a < b[0]
        }
        ConditionOperator.LessThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a <= b[0]
        }
        ConditionOperator.In -> {
            return b.contains(a)
        }
        ConditionOperator.NotIn -> {
            return !b.contains(a)
        }
        ConditionOperator.Between -> {
            if (b.count() != 2) {
                return false
            }
            return b[0] <= a && a <= b[1]
        }
        else -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
    }
}


internal fun compareLong(a: Long, b: List<Long>, op: ConditionOperator): Boolean {
    return when (op) {
        ConditionOperator.Equal -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
        ConditionOperator.NotEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a != b[0]
        }
        ConditionOperator.GreaterThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a > b[0]
        }
        ConditionOperator.GreaterThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a >= b[0]
        }
        ConditionOperator.LessThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a < b[0]
        }
        ConditionOperator.LessThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a <= b[0]
        }
        ConditionOperator.In -> {
            return b.contains(a)
        }
        ConditionOperator.NotIn -> {
            return !b.contains(a)
        }
        ConditionOperator.Between -> {
            if (b.count() != 2) {
                return false
            }
            return b[0] <= a && a <= b[1]
        }
        else -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
    }
}

internal fun compareDouble(a: Double, b: List<Double>, op: ConditionOperator): Boolean {
    return when (op) {
        ConditionOperator.Equal -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
        ConditionOperator.NotEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a != b[0]
        }
        ConditionOperator.GreaterThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a > b[0]
        }
        ConditionOperator.GreaterThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a >= b[0]
        }
        ConditionOperator.LessThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a < b[0]
        }
        ConditionOperator.LessThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a <= b[0]
        }
        ConditionOperator.In -> {
            return b.contains(a)
        }
        ConditionOperator.NotIn -> {
            return !b.contains(a)
        }
        ConditionOperator.Between -> {
            if (b.count() != 2) {
                return false
            }
            return b[0] <= a && a <= b[1]
        }
        else -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
    }
}


internal fun compareString(a: String, b: List<String>, op: ConditionOperator): Boolean {
    return when (op) {
        ConditionOperator.Regex -> {
            if (b.isEmpty()) {
                return false
            }
            return containsPattern(a, b[0])
        }
        ConditionOperator.Equal -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
        ConditionOperator.NotEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a != b[0]
        }
        ConditionOperator.GreaterThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a > b[0]
        }
        ConditionOperator.GreaterThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a >= b[0]
        }
        ConditionOperator.LessThan -> {
            if (b.isEmpty()) {
                return false
            }
            return a < b[0]
        }
        ConditionOperator.LessThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return a <= b[0]
        }
        ConditionOperator.In -> {
            return b.contains(a)
        }
        ConditionOperator.NotIn -> {
            return !b.contains(a)
        }
        ConditionOperator.Between -> {
            if (b.count() != 2) {
                return false
            }
            return b[0] <= a && a <= b[1]
        }
        else -> {
            if (b.isEmpty()) {
                return false
            }
            return a == b[0]
        }
    }
}

internal fun compareSemver(a: String, b: List<String>, op: ConditionOperator): Boolean {
    return when (op) {
        ConditionOperator.Equal -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) == 0
        }
        ConditionOperator.NotEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) != 0
        }
        ConditionOperator.GreaterThan -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) > 0
        }
        ConditionOperator.GreaterThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) >= 0
        }
        ConditionOperator.LessThan -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) < 0
        }
        ConditionOperator.LessThanOrEqual -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) <= 0
        }
        ConditionOperator.In -> {
            return b.any { value ->
                compareSemverAsComparisonResult(a, value) == 0
            }
        }
        ConditionOperator.NotIn -> {
            return b.none { value ->
                compareSemverAsComparisonResult(a, value) == 0
            }
        }
        ConditionOperator.Between -> {
            if (b.count() != 2) {
                return false
            }
            val left = compareSemverAsComparisonResult(a, b[0])
            val right = compareSemverAsComparisonResult(a, b[1])
            return left >= 0 && right <= 0
        }
        else -> {
            if (b.isEmpty()) {
                return false
            }
            return compareSemverAsComparisonResult(a, b[0]) == 0
        }
    }
}

private const val ASTERISK_IDENTIFIER: Int = -1

/**
 * <semver> ::= <version core>
 *            | <version core> "-" <pre-release>
 *            | <version core> "+" <build>
 *            | <version core> "-" <pre-release> "+" <build>
 * <version core> ::= <major> "." <minor> "." <patch>
 */
internal data class Semver(
    val major: Int = 0,
    val minor: Int = 0,
    val patch: Int = 0,
    val prerelease: String = "",
    val build: String = "",
) {
    fun compareTo(other: SemverConstraint): Int {
        var majorComparison = this.major.compareTo(other.major)
        if (other.major == ASTERISK_IDENTIFIER) { // when it's a.b.c and *
            majorComparison = 0
        }

        var minorComparison = this.minor.compareTo(other.minor)
        if (other.minor == ASTERISK_IDENTIFIER) { // a.b.c and x.*
            minorComparison = 0
        }

        var patchComparison = this.patch.compareTo(other.patch)
        if (other.patch == ASTERISK_IDENTIFIER) { // a.b.c and x.y.*
            patchComparison = 0
        }

        var prereleaseComparison = this.prerelease.compareTo(other.prerelease ?: "")
        if (other.prerelease == null) {
            prereleaseComparison = 0
        }

        val versionComparisons = listOf(
            majorComparison,
            minorComparison,
            patchComparison,
            prereleaseComparison
        )
        val versionComparison = versionComparisons.firstOrNull {
            it != 0
        } ?: 0 // when every comparison is 0, it's 0
        if (versionComparison < 0) return -1
        else if (versionComparison == 0) return 0
        else return 1
    }

    companion object {
        fun decode(value: String): Semver {
            val semver = SemverConstraint.decode(value)
            return Semver(
                major = if (semver.major == ASTERISK_IDENTIFIER) 0 else semver.major,
                minor = if (semver.minor == ASTERISK_IDENTIFIER) 0 else semver.minor,
                patch = if (semver.patch == ASTERISK_IDENTIFIER) 0 else semver.patch,
                build = semver.build ?: "",
                prerelease = semver.prerelease ?: ""
            )
        }
    }
}

internal data class SemverConstraint(
    val major: Int = ASTERISK_IDENTIFIER,
    val minor: Int = ASTERISK_IDENTIFIER,
    val patch: Int = ASTERISK_IDENTIFIER,
    val prerelease: String? = null,
    val build: String? = null,
) {
    companion object {
        fun decode(value: String): SemverConstraint {
            if (value.isEmpty()) return SemverConstraint()

            // 1. parse the build metadata part
            val components1 = value.split("+")
            var versionCoreAndPrerelease = components1[0]
            var build: String? = null
            if (components1.size >= 2) {
                build = components1[1]
            }
            if (versionCoreAndPrerelease.isEmpty()) return SemverConstraint(build = build)

            // 2. parse the prerelease part
            val components2 = versionCoreAndPrerelease.split("-")
            var versionCore = components2[0]
            var prerelease: String? = null
            if (components2.size >= 2) {
                prerelease = components2[1]
            }
            if (versionCore.isEmpty()) return SemverConstraint(prerelease = prerelease, build = build)

            // 3. parse the version core part
            val components3 = versionCore.split(".")
            var major: Int = ASTERISK_IDENTIFIER
            var minor: Int = ASTERISK_IDENTIFIER
            var patch: Int = ASTERISK_IDENTIFIER
            if (components3.size >= 3) {
                patch = components3[2].toIntOrNull() ?: ASTERISK_IDENTIFIER
            }
            if (components3.size >= 2) {
                minor = components3[1].toIntOrNull() ?: ASTERISK_IDENTIFIER
            }
            if (components3.isNotEmpty()) {
                major = components3[0].toIntOrNull() ?: ASTERISK_IDENTIFIER
            }
            return SemverConstraint(major, minor, patch, prerelease = prerelease, build = build)
        }
    }
}

internal fun compareSemverAsComparisonResult(lhs: String, rhs: String): Int {
    val lhsSemver = Semver.decode(lhs)
    val rhsSemverConstraint = SemverConstraint.decode(rhs)
    return lhsSemver.compareTo(rhsSemverConstraint)
}

internal fun containsPattern(input: String, pattern: String): Boolean {
    return try {
        val regex = Pattern.compile(pattern)
        regex.matcher(input).find()
    } catch (e: PatternSyntaxException) {
        false
    }
}