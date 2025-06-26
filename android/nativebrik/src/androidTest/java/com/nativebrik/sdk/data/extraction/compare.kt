package com.nativebrik.sdk.data.extraction

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.nativebrik.sdk.schema.ConditionOperator
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CompareTest {

    private data class Case<I, O>(
        val name: String,
        val input: I,
        val expected: O
    )

    @Test
    fun should_compareInteger_works() {
        val cases: List<Case<Triple<Int, List<Int>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: 0 == 0 = true", Triple(0, listOf(0), ConditionOperator.Equal), true),
            Case("eq: 0 == none = false", Triple(0, listOf(), ConditionOperator.Equal), false),
            Case("eq: 0 == 1 = false", Triple(0, listOf(1), ConditionOperator.Equal), false),

            Case("neq: 0 != 0 = false", Triple(0, listOf(0), ConditionOperator.NotEqual), false),
            Case("neq: 0 != none = false", Triple(0, listOf(), ConditionOperator.NotEqual), false),
            Case("neq: 0 != 1 = true", Triple(0, listOf(1), ConditionOperator.NotEqual), true),

            Case("gt: 0 > 0 = false", Triple(0, listOf(0), ConditionOperator.GreaterThan), false),
            Case("gt: 0 > -1 = true", Triple(0, listOf(-1), ConditionOperator.GreaterThan), true),
            Case("gt: 0 > 1 = false", Triple(0, listOf(1), ConditionOperator.GreaterThan), false),

            Case("gte: 0 >= 0 = true", Triple(0, listOf(0), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 0 >= -1 = true", Triple(0, listOf(-1), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 0 >= 1 = false", Triple(0, listOf(1), ConditionOperator.GreaterThanOrEqual), false),

            Case("lt: 0 < 0 = false", Triple(0, listOf(0), ConditionOperator.LessThan), false),
            Case("lt: 0 < -1 = false", Triple(0, listOf(-1), ConditionOperator.LessThan), false),
            Case("lt: 0 < 1 = true", Triple(0, listOf(1), ConditionOperator.LessThan), true),

            Case("lte: 0 <= 0 = true", Triple(0, listOf(0), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 0 <= -1 = false", Triple(0, listOf(-1), ConditionOperator.LessThanOrEqual), false),
            Case("lte: 0 <= 1 = true", Triple(0, listOf(1), ConditionOperator.LessThanOrEqual), true),

            Case("in: 0 is in [0, 1, 2] = true", Triple(0, listOf(0, 1, 2), ConditionOperator.In), true),
            Case("in: 0 is in [1, 2, 3] = false", Triple(0, listOf(1, 2, 3), ConditionOperator.In), false),

            Case("not in: 0 is not in [0, 1, 2] = false", Triple(0, listOf(0, 1, 2), ConditionOperator.NotIn), false),
            Case("not in: 0 is not in [1, 2, 3] = true", Triple(0, listOf(1, 2, 3), ConditionOperator.NotIn), true),

            Case("between: 0 is between [-100, 100] = true", Triple(0, listOf(-100, 100), ConditionOperator.Between), true),
            Case("between: 0 is between [100, 200] = false", Triple(0, listOf(100, 200), ConditionOperator.Between), false),
            Case("between: 0 is between [empty] = false", Triple(0, listOf(), ConditionOperator.Between), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareInteger(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_compareDouble_works() {
        val cases: List<Case<Triple<Double, List<Double>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: 0.0 == 0.0 = true", Triple(0.0, listOf(0.0), ConditionOperator.Equal), true),
            Case("eq: 0.0 == none = false", Triple(0.0, listOf(), ConditionOperator.Equal), false),
            Case("eq: 0.0 == 1.5 = false", Triple(0.0, listOf(1.5), ConditionOperator.Equal), false),

            Case("neq: 0.0 != 0.0 = false", Triple(0.0, listOf(0.0), ConditionOperator.NotEqual), false),
            Case("neq: 0.0 != none = false", Triple(0.0, listOf(), ConditionOperator.NotEqual), false),
            Case("neq: 0.0 != 1.5 = true", Triple(0.0, listOf(1.5), ConditionOperator.NotEqual), true),

            Case("gt: 1.5 > 1.0 = true", Triple(1.5, listOf(1.0), ConditionOperator.GreaterThan), true),
            Case("gt: 1.0 > 1.0 = false", Triple(1.0, listOf(1.0), ConditionOperator.GreaterThan), false),
            Case("gt: 0.5 > 1.0 = false", Triple(0.5, listOf(1.0), ConditionOperator.GreaterThan), false),

            Case("gte: 1.0 >= 1.0 = true", Triple(1.0, listOf(1.0), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 1.5 >= 1.0 = true", Triple(1.5, listOf(1.0), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 0.5 >= 1.0 = false", Triple(0.5, listOf(1.0), ConditionOperator.GreaterThanOrEqual), false),

            Case("lt: 0.5 < 1.0 = true", Triple(0.5, listOf(1.0), ConditionOperator.LessThan), true),
            Case("lt: 1.0 < 1.0 = false", Triple(1.0, listOf(1.0), ConditionOperator.LessThan), false),
            Case("lt: 1.5 < 1.0 = false", Triple(1.5, listOf(1.0), ConditionOperator.LessThan), false),

            Case("lte: 1.0 <= 1.0 = true", Triple(1.0, listOf(1.0), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 0.5 <= 1.0 = true", Triple(0.5, listOf(1.0), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 1.5 <= 1.0 = false", Triple(1.5, listOf(1.0), ConditionOperator.LessThanOrEqual), false),

            Case("in: 1.5 is in [1.0, 1.5, 2.0] = true", Triple(1.5, listOf(1.0, 1.5, 2.0), ConditionOperator.In), true),
            Case("in: 1.5 is in [2.0, 2.5, 3.0] = false", Triple(1.5, listOf(2.0, 2.5, 3.0), ConditionOperator.In), false),

            Case("not in: 1.5 is not in [1.0, 1.5, 2.0] = false", Triple(1.5, listOf(1.0, 1.5, 2.0), ConditionOperator.NotIn), false),
            Case("not in: 1.5 is not in [2.0, 2.5, 3.0] = true", Triple(1.5, listOf(2.0, 2.5, 3.0), ConditionOperator.NotIn), true),

            Case("between: 1.5 is between [1.0, 2.0] = true", Triple(1.5, listOf(1.0, 2.0), ConditionOperator.Between), true),
            Case("between: 1.5 is between [2.0, 3.0] = false", Triple(1.5, listOf(2.0, 3.0), ConditionOperator.Between), false),
            Case("between: 1.5 is between [empty] = false", Triple(1.5, listOf(), ConditionOperator.Between), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareDouble(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_compareLong_works() {
        val cases: List<Case<Triple<Long, List<Long>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: 0L == 0L = true", Triple(0L, listOf(0L), ConditionOperator.Equal), true),
            Case("eq: 0L == none = false", Triple(0L, listOf(), ConditionOperator.Equal), false),
            Case("eq: 0L == 1L = false", Triple(0L, listOf(1L), ConditionOperator.Equal), false),

            Case("neq: 0L != 0L = false", Triple(0L, listOf(0L), ConditionOperator.NotEqual), false),
            Case("neq: 0L != none = false", Triple(0L, listOf(), ConditionOperator.NotEqual), false),
            Case("neq: 0L != 1L = true", Triple(0L, listOf(1L), ConditionOperator.NotEqual), true),

            Case("gt: 100L > 50L = true", Triple(100L, listOf(50L), ConditionOperator.GreaterThan), true),
            Case("gt: 50L > 50L = false", Triple(50L, listOf(50L), ConditionOperator.GreaterThan), false),
            Case("gt: 25L > 50L = false", Triple(25L, listOf(50L), ConditionOperator.GreaterThan), false),

            Case("gte: 50L >= 50L = true", Triple(50L, listOf(50L), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 100L >= 50L = true", Triple(100L, listOf(50L), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 25L >= 50L = false", Triple(25L, listOf(50L), ConditionOperator.GreaterThanOrEqual), false),

            Case("lt: 25L < 50L = true", Triple(25L, listOf(50L), ConditionOperator.LessThan), true),
            Case("lt: 50L < 50L = false", Triple(50L, listOf(50L), ConditionOperator.LessThan), false),
            Case("lt: 100L < 50L = false", Triple(100L, listOf(50L), ConditionOperator.LessThan), false),

            Case("lte: 50L <= 50L = true", Triple(50L, listOf(50L), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 25L <= 50L = true", Triple(25L, listOf(50L), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 100L <= 50L = false", Triple(100L, listOf(50L), ConditionOperator.LessThanOrEqual), false),

            Case("in: 50L is in [25L, 50L, 100L] = true", Triple(50L, listOf(25L, 50L, 100L), ConditionOperator.In), true),
            Case("in: 50L is in [100L, 200L, 300L] = false", Triple(50L, listOf(100L, 200L, 300L), ConditionOperator.In), false),

            Case("not in: 50L is not in [25L, 50L, 100L] = false", Triple(50L, listOf(25L, 50L, 100L), ConditionOperator.NotIn), false),
            Case("not in: 50L is not in [100L, 200L, 300L] = true", Triple(50L, listOf(100L, 200L, 300L), ConditionOperator.NotIn), true),

            Case("between: 50L is between [25L, 100L] = true", Triple(50L, listOf(25L, 100L), ConditionOperator.Between), true),
            Case("between: 50L is between [100L, 200L] = false", Triple(50L, listOf(100L, 200L), ConditionOperator.Between), false),
            Case("between: 50L is between [empty] = false", Triple(50L, listOf(), ConditionOperator.Between), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareLong(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_compareString_works() {
        val cases: List<Case<Triple<String, List<String>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: 'hello' == 'hello' = true", Triple("hello", listOf("hello"), ConditionOperator.Equal), true),
            Case("eq: 'hello' == none = false", Triple("hello", listOf(), ConditionOperator.Equal), false),
            Case("eq: 'hello' == 'world' = false", Triple("hello", listOf("world"), ConditionOperator.Equal), false),

            Case("neq: 'hello' != 'hello' = false", Triple("hello", listOf("hello"), ConditionOperator.NotEqual), false),
            Case("neq: 'hello' != none = false", Triple("hello", listOf(), ConditionOperator.NotEqual), false),
            Case("neq: 'hello' != 'world' = true", Triple("hello", listOf("world"), ConditionOperator.NotEqual), true),

            Case("gt: 'world' > 'hello' = true", Triple("world", listOf("hello"), ConditionOperator.GreaterThan), true),
            Case("gt: 'hello' > 'hello' = false", Triple("hello", listOf("hello"), ConditionOperator.GreaterThan), false),
            Case("gt: 'apple' > 'banana' = false", Triple("apple", listOf("banana"), ConditionOperator.GreaterThan), false),

            Case("gte: 'hello' >= 'hello' = true", Triple("hello", listOf("hello"), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 'world' >= 'hello' = true", Triple("world", listOf("hello"), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: 'apple' >= 'banana' = false", Triple("apple", listOf("banana"), ConditionOperator.GreaterThanOrEqual), false),

            Case("lt: 'apple' < 'banana' = true", Triple("apple", listOf("banana"), ConditionOperator.LessThan), true),
            Case("lt: 'hello' < 'hello' = false", Triple("hello", listOf("hello"), ConditionOperator.LessThan), false),
            Case("lt: 'world' < 'hello' = false", Triple("world", listOf("hello"), ConditionOperator.LessThan), false),

            Case("lte: 'hello' <= 'hello' = true", Triple("hello", listOf("hello"), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 'apple' <= 'banana' = true", Triple("apple", listOf("banana"), ConditionOperator.LessThanOrEqual), true),
            Case("lte: 'world' <= 'hello' = false", Triple("world", listOf("hello"), ConditionOperator.LessThanOrEqual), false),

            Case("in: 'hello' is in ['hi', 'hello', 'world'] = true", Triple("hello", listOf("hi", "hello", "world"), ConditionOperator.In), true),
            Case("in: 'hello' is in ['hi', 'world', 'test'] = false", Triple("hello", listOf("hi", "world", "test"), ConditionOperator.In), false),

            Case("not in: 'hello' is not in ['hi', 'hello', 'world'] = false", Triple("hello", listOf("hi", "hello", "world"), ConditionOperator.NotIn), false),
            Case("not in: 'hello' is not in ['hi', 'world', 'test'] = true", Triple("hello", listOf("hi", "world", "test"), ConditionOperator.NotIn), true),

            Case("between: 'hello' is between ['apple', 'world'] = true", Triple("hello", listOf("apple", "world"), ConditionOperator.Between), true),
            Case("between: 'hello' is between ['world', 'zebra'] = false", Triple("hello", listOf("world", "zebra"), ConditionOperator.Between), false),
            Case("between: 'hello' is between [empty] = false", Triple("hello", listOf(), ConditionOperator.Between), false),

            Case("regex: 'hello123' matches '[a-z]+[0-9]+' = true", Triple("hello123", listOf("[a-z]+[0-9]+"), ConditionOperator.Regex), true),
            Case("regex: 'hello' matches '[0-9]+' = false", Triple("hello", listOf("[0-9]+"), ConditionOperator.Regex), false),
            Case("regex: 'test' matches invalid pattern = false", Triple("test", listOf("["), ConditionOperator.Regex), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareString(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_compareBoolean_works() {
        val cases: List<Case<Triple<Boolean, List<Boolean>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: true == true = true", Triple(true, listOf(true), ConditionOperator.Equal), true),
            Case("eq: true == none = false", Triple(true, listOf(), ConditionOperator.Equal), false),
            Case("eq: true == false = false", Triple(true, listOf(false), ConditionOperator.Equal), false),
            Case("eq: false == false = true", Triple(false, listOf(false), ConditionOperator.Equal), true),

            Case("neq: true != true = false", Triple(true, listOf(true), ConditionOperator.NotEqual), false),
            Case("neq: true != none = false", Triple(true, listOf(), ConditionOperator.NotEqual), false),
            Case("neq: true != false = true", Triple(true, listOf(false), ConditionOperator.NotEqual), true),
            Case("neq: false != false = false", Triple(false, listOf(false), ConditionOperator.NotEqual), false),

            Case("in: true is in [true, false] = true", Triple(true, listOf(true, false), ConditionOperator.In), true),
            Case("in: true is in [false] = false", Triple(true, listOf(false), ConditionOperator.In), false),
            Case("in: false is in [false] = true", Triple(false, listOf(false), ConditionOperator.In), true),

            Case("not in: true is not in [true, false] = false", Triple(true, listOf(true, false), ConditionOperator.NotIn), false),
            Case("not in: true is not in [false] = true", Triple(true, listOf(false), ConditionOperator.NotIn), true),
            Case("not in: false is not in [false] = false", Triple(false, listOf(false), ConditionOperator.NotIn), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareBoolean(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_compareSemver_works() {
        val cases: List<Case<Triple<String, List<String>, ConditionOperator>, Boolean>> = listOf(
            Case("eq: '1.0.0' == '1.0.0' = true", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.Equal), true),
            Case("eq: '1.0.0' == none = false", Triple("1.0.0", listOf(), ConditionOperator.Equal), false),
            Case("eq: '1.0.0' == '1.0.1' = false", Triple("1.0.0", listOf("1.0.1"), ConditionOperator.Equal), false),
            Case("eq: '1.0' == '1.0.0' = true", Triple("1.0", listOf("1.0.0"), ConditionOperator.Equal), true),

            Case("neq: '1.0.0' != '1.0.0' = false", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.NotEqual), false),
            Case("neq: '1.0.0' != none = false", Triple("1.0.0", listOf(), ConditionOperator.NotEqual), false),
            Case("neq: '1.0.0' != '1.0.1' = true", Triple("1.0.0", listOf("1.0.1"), ConditionOperator.NotEqual), true),

            Case("gt: '1.1.0' > '1.0.0' = true", Triple("1.1.0", listOf("1.0.0"), ConditionOperator.GreaterThan), true),
            Case("gt: '1.0.0' > '1.0.0' = false", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.GreaterThan), false),
            Case("gt: '1.0.0' > '1.1.0' = false", Triple("1.0.0", listOf("1.1.0"), ConditionOperator.GreaterThan), false),

            Case("gte: '1.0.0' >= '1.0.0' = true", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: '1.1.0' >= '1.0.0' = true", Triple("1.1.0", listOf("1.0.0"), ConditionOperator.GreaterThanOrEqual), true),
            Case("gte: '1.0.0' >= '1.1.0' = false", Triple("1.0.0", listOf("1.1.0"), ConditionOperator.GreaterThanOrEqual), false),

            Case("lt: '1.0.0' < '1.1.0' = true", Triple("1.0.0", listOf("1.1.0"), ConditionOperator.LessThan), true),
            Case("lt: '1.0.0' < '1.0.0' = false", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.LessThan), false),
            Case("lt: '1.1.0' < '1.0.0' = false", Triple("1.1.0", listOf("1.0.0"), ConditionOperator.LessThan), false),

            Case("lte: '1.0.0' <= '1.0.0' = true", Triple("1.0.0", listOf("1.0.0"), ConditionOperator.LessThanOrEqual), true),
            Case("lte: '1.0.0' <= '1.1.0' = true", Triple("1.0.0", listOf("1.1.0"), ConditionOperator.LessThanOrEqual), true),
            Case("lte: '1.1.0' <= '1.0.0' = false", Triple("1.1.0", listOf("1.0.0"), ConditionOperator.LessThanOrEqual), false),

            Case("in: '1.0.0' is in ['1.0.0', '1.1.0'] = true", Triple("1.0.0", listOf("1.0.0", "1.1.0"), ConditionOperator.In), true),
            Case("in: '1.0.0' is in ['1.1.0', '1.2.0'] = false", Triple("1.0.0", listOf("1.1.0", "1.2.0"), ConditionOperator.In), false),

            Case("not in: '1.0.0' is not in ['1.0.0', '1.1.0'] = false", Triple("1.0.0", listOf("1.0.0", "1.1.0"), ConditionOperator.NotIn), false),
            Case("not in: '1.0.0' is not in ['1.1.0', '1.2.0'] = true", Triple("1.0.0", listOf("1.1.0", "1.2.0"), ConditionOperator.NotIn), true),

            Case("between: '1.1.0' is between ['1.0.0', '1.2.0'] = true", Triple("1.1.0", listOf("1.0.0", "1.2.0"), ConditionOperator.Between), true),
            Case("between: '1.0.0' is between ['1.1.0', '1.2.0'] = false", Triple("1.0.0", listOf("1.1.0", "1.2.0"), ConditionOperator.Between), false),
            Case("between: '1.0.0' is between [empty] = false", Triple("1.0.0", listOf(), ConditionOperator.Between), false),
        )

        cases.forEach { c ->
            val (a, b, op) = c.input
            val actual = compareSemver(a, b, op)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }

    @Test
    fun should_parseStringToBoolean_works() {
        val cases: List<Case<String, Boolean>> = listOf(
            Case("'true' = true", "true", true),
            Case("'TRUE' = true", "TRUE", true),
            Case("'yes' = true", "yes", true),
            Case("'1' = true", "1", true),
            Case("'on' = true", "on", true),
            Case("'anything' = true", "anything", true),
            Case("'  spaced  ' = true", "  spaced  ", true),

            Case("'false' = false", "false", false),
            Case("'FALSE' = false", "FALSE", false),
            Case("'no' = false", "no", false),
            Case("'NO' = false", "NO", false),
            Case("'0' = false", "0", false),
            Case("'nil' = false", "nil", false),
            Case("'NIL' = false", "NIL", false),
            Case("'off' = false", "off", false),
            Case("'OFF' = false", "OFF", false),
            Case("'' (empty) = false", "", false),
            Case("'  ' (whitespace) = false", "  ", false),
        )

        cases.forEach { c ->
            val actual = parseStringToBoolean(c.input)
            Assert.assertEquals("case=\"${c.name}\"", c.expected, actual)
        }
    }
}
