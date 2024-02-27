package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.data.user.UserPropertyType
import com.nativebrik.sdk.schema.ConditionOperator
import org.junit.Assert.assertEquals
import org.junit.Test

class ComparisonUnitTest {
    private val strProp = UserProperty(name = "str", value = "Hello", type = UserPropertyType.STRING)
    private val intProp = UserProperty(name = "int", value = "100", type = UserPropertyType.INTEGER)
    private val doubleProp = UserProperty(name = "double", value = "12.3", type = UserPropertyType.DOUBLE)
    private val semverProp = UserProperty(name = "semver", value = "1.1.1", type = UserPropertyType.SEMVER)
    private val timeProp = UserProperty(name = "time", value = "2011-10-05T14:48:00.000Z", type = UserPropertyType.TIMESTAMPZ)

    @Test
    fun shouldCompareInteger() {
        assertEquals(true, comparePropWithConditionValue(this.intProp, "100 ", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.intProp, "100", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, "200", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, "90", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, "110", ConditionOperator.LessThanOrEqual))

        assertEquals(true, comparePropWithConditionValue(this.intProp, "10, 50, 100", ConditionOperator.In))
        assertEquals(false, comparePropWithConditionValue(this.intProp, "10, 50, 99, 120", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.intProp, "10, 50, 90", ConditionOperator.NotIn))
        assertEquals(true, comparePropWithConditionValue(this.intProp, "99, 101", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.intProp, "98, 99", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.intProp, "98", ConditionOperator.Between))
    }

    @Test
    fun shouldCompareDouble() {
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "12.3 ", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, "12.3", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "20.0", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "10", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "13", ConditionOperator.LessThanOrEqual))

        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "10, 10.2, 12.3", ConditionOperator.In))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, "0.0, 11.1, 11, 12", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "0.0, 11.1, 11, 12", ConditionOperator.NotIn))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, "0, 20", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, "30, 40", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, "1", ConditionOperator.Between))
    }

    @Test
    fun shouldCompareString() {
        assertEquals(true, comparePropWithConditionValue(this.strProp, "[a-zA-Z]+", ConditionOperator.Regex))
        assertEquals(false, comparePropWithConditionValue(this.strProp, "[0-9]+", ConditionOperator.Regex))

        assertEquals(true, comparePropWithConditionValue(this.strProp, "Hello", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.strProp, "Hello", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.strProp, "Hello ", ConditionOperator.NotEqual))

        assertEquals(true, comparePropWithConditionValue(this.strProp, "Hello,Hello World", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.strProp, "X,Y,Z", ConditionOperator.NotIn))
    }

    @Test
    fun shouldCompareSemver() {
        assertEquals(true, comparePropWithConditionValue(this.semverProp, "1", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.semverProp, "1.1", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.semverProp, "1.1.1", ConditionOperator.Equal))
    }

    @Test
    fun shouldCompareTimestamp() {
        assertEquals(true, comparePropWithConditionValue(this.timeProp, "2011-10-05T14:48:00.000Z", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.timeProp, "2011-10-05T14:49:00.000Z", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.timeProp, "2011-10-05T14:47:00.000Z", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.timeProp, "2011-10-05T14:49:00.000Z", ConditionOperator.LessThanOrEqual))
    }
}

class SemverUnitTest {
    @Test
    fun shouldDecodeSemver() {
        assertEquals(Semver(), Semver.decode(""))
        assertEquals(Semver(1), Semver.decode("1"))
        assertEquals(Semver(1,2), Semver.decode("1.2"))
        assertEquals(Semver(1,2,3), Semver.decode("1.2.3"))
        assertEquals(Semver(1,2,3, "test"), Semver.decode("1.2.3-test"))

    }

    @Test
    fun shouldDecodeSemverConstraint() {
        assertEquals(SemverConstraint(), SemverConstraint.decode(""))
        assertEquals(SemverConstraint(), SemverConstraint.decode("*"))
        assertEquals(SemverConstraint(1), SemverConstraint.decode("1.*"))
        assertEquals(SemverConstraint(1,2), SemverConstraint.decode("1.2"))
        assertEquals(SemverConstraint(1,2), SemverConstraint.decode("1.2.*"))
        assertEquals(SemverConstraint(1,2,3, "test"), SemverConstraint.decode("1.2.3-test"))
        assertEquals(SemverConstraint(1,2,3, build = "build"), SemverConstraint.decode("1.2.3+build"))
        assertEquals(SemverConstraint(1,2,3, "test", build = "build"), SemverConstraint.decode("1.2.3-test+build"))
    }

    @Test
    fun shouldCompareToWork() {
        val version = Semver.decode("1.2.3-test")
        assertEquals(0, version.compareTo(SemverConstraint.decode("")))
        assertEquals(0, version.compareTo(SemverConstraint.decode("*")))
        assertEquals(0, version.compareTo(SemverConstraint.decode("1")))
        assertEquals(1, version.compareTo(SemverConstraint.decode("0")))
        assertEquals(-1, version.compareTo(SemverConstraint.decode("2")))

        assertEquals(0, version.compareTo(SemverConstraint.decode("1.*")))
        assertEquals(0, version.compareTo(SemverConstraint.decode("1.2")))
        assertEquals(1, version.compareTo(SemverConstraint.decode("1.1")))
        assertEquals(-1, version.compareTo(SemverConstraint.decode("1.3")))

        assertEquals(0, version.compareTo(SemverConstraint.decode("1.2.*")))
        assertEquals(0, version.compareTo(SemverConstraint.decode("1.2.3")))
        assertEquals(1, version.compareTo(SemverConstraint.decode("1.2.2")))
        assertEquals(-1, version.compareTo(SemverConstraint.decode("1.2.4")))

        assertEquals(0, version.compareTo(SemverConstraint.decode("1.2.3-test")))
        assertEquals(1, version.compareTo(SemverConstraint.decode("1.2.3-te")))
        assertEquals(-1, version.compareTo(SemverConstraint.decode("1.2.3-testing")))
    }
}
