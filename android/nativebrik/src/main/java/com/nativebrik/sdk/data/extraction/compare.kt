package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.data.user.UserPropertyType
import com.nativebrik.sdk.schema.ConditionOperator
import java.text.SimpleDateFormat
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException
import kotlin.math.absoluteValue

fun comparePropWithConditionValue(prop: UserProperty, value: String, op: ConditionOperator): Boolean {
    val values = value.split(",")
    return when (prop.type) {
        UserPropertyType.INTEGER -> {
            val propValue = prop.value.toIntOrNull() ?: 0
            val conditionValues = values.map { it.toIntOrNull() ?: 0 }
            compareInteger(a = propValue, b = conditionValues, op = op)
        }
        UserPropertyType.STRING -> {
            val strings = values.map { it }
            compareString(a = prop.value, b = strings, op = op)
        }
        UserPropertyType.SEMVER -> {
            val strings = values.map { it }
            compareSemver(a = prop.value, b = strings, op = op)
        }
        UserPropertyType.TIMESTAMPZ -> {
            try {
                val dateFormatter = SimpleDateFormat()
                val propValue = dateFormatter?.parse(prop.value)?.time ?: 0
                val conditionValues = values.map { dateFormatter.parse(it)?.time?.div(1000) ?: 0 }
                compareLong(a = propValue, b = conditionValues, op = op)
            } catch (e: Exception) {
                compareLong(a = 0, b = emptyList(), op = op)
            }
        }
        else -> false
    }
}

fun compareInteger(a: Int, b: List<Int>, op: ConditionOperator): Boolean {
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


fun compareLong(a: Long, b: List<Long>, op: ConditionOperator): Boolean {
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


fun compareString(a: String, b: List<String>, op: ConditionOperator): Boolean {
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

fun compareSemver(a: String, b: List<String>, op: ConditionOperator): Boolean {
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


fun compareSemverAsComparisonResult(lhs: String, rhs: String): Int {
    val versionDelimiter = "."
    var lhsComponents = lhs.split(versionDelimiter)
    var rhsComponents = rhs.split(versionDelimiter)
    val zeroDiff = lhsComponents.size - rhsComponents.size
    if (zeroDiff == 0) {
        // Same format, compare normally
        return lhs.compareTo(rhs, ignoreCase = false)
    } else {
        // append zeros to suffix to compare with the same format v'x' -> v'x.0.0'
        val zeros = List(zeroDiff.absoluteValue) { "0" }
        if (zeroDiff > 0) {
            rhsComponents = rhsComponents + zeros
        } else {
            lhsComponents = lhsComponents + zeros
        }
        return lhsComponents.joinToString(versionDelimiter)
            .compareTo(rhsComponents.joinToString(versionDelimiter), ignoreCase = false)
    }
}

fun containsPattern(input: String, pattern: String): Boolean {
    return try {
        val regex = Pattern.compile(pattern)
        regex.matcher(input).find()
    } catch (e: PatternSyntaxException) {
        false
    }
}