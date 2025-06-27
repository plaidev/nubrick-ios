package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.schema.ConditionOperator
import com.nativebrik.sdk.schema.UserPropertyType
import org.junit.Assert.assertEquals
import org.junit.Test

class ComparisonUnitTest {
    private val strProp = UserProperty(name = "str", value = "Hello", type = UserPropertyType.STRING)
    private val intProp = UserProperty(name = "int", value = "100", type = UserPropertyType.INTEGER)
    private val doubleProp = UserProperty(name = "double", value = "12.3", type = UserPropertyType.DOUBLE)
    private val semverProp = UserProperty(name = "semver", value = "1.1.1", type = UserPropertyType.SEMVER)
    private val timeProp = UserProperty(name = "time", value = "2011-10-05T14:48:00.000Z", type = UserPropertyType.TIMESTAMPZ)
    private val boolProp = UserProperty(name = "bool", value = "false", type = UserPropertyType.BOOLEAN)

    @Test
    fun shouldCompareWithPropTypeOverride_asType() {
        assertEquals(true, comparePropWithConditionValue(
            UserProperty(name = "str", value = "12.3", type = UserPropertyType.STRING),
            UserPropertyType.SEMVER, "12", ConditionOperator.Equal)
        )
    }

    @Test
    fun shouldCompareInteger() {
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "100 ", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.intProp, null, "100", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "200", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "90", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "110", ConditionOperator.LessThanOrEqual))

        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "10, 50, 100", ConditionOperator.In))
        assertEquals(false, comparePropWithConditionValue(this.intProp, null, "10, 50, 99, 120", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "10, 50, 90", ConditionOperator.NotIn))
        assertEquals(true, comparePropWithConditionValue(this.intProp, null, "99, 101", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.intProp, null, "98, 99", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.intProp, null, "98", ConditionOperator.Between))
    }

    @Test
    fun shouldCompareDouble() {
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "12.3 ", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, null, "12.3", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "20.0", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "10", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "13", ConditionOperator.LessThanOrEqual))

        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "10, 10.2, 12.3", ConditionOperator.In))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, null, "0.0, 11.1, 11, 12", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "0.0, 11.1, 11, 12", ConditionOperator.NotIn))
        assertEquals(true, comparePropWithConditionValue(this.doubleProp, null, "0, 20", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, null, "30, 40", ConditionOperator.Between))
        assertEquals(false, comparePropWithConditionValue(this.doubleProp, null, "1", ConditionOperator.Between))
    }

    @Test
    fun shouldCompareString() {
        assertEquals(true, comparePropWithConditionValue(this.strProp, null, "[a-zA-Z]+", ConditionOperator.Regex))
        assertEquals(false, comparePropWithConditionValue(this.strProp, null, "[0-9]+", ConditionOperator.Regex))

        assertEquals(true, comparePropWithConditionValue(this.strProp, null, "Hello", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.strProp, null, "Hello", ConditionOperator.NotEqual))
        assertEquals(true, comparePropWithConditionValue(this.strProp, null, "Hello ", ConditionOperator.NotEqual))

        assertEquals(true, comparePropWithConditionValue(this.strProp, null, "Hello,Hello World", ConditionOperator.In))
        assertEquals(true, comparePropWithConditionValue(this.strProp, null, "X,Y,Z", ConditionOperator.NotIn))
    }

    @Test
    fun shouldCompareSemver() {
        assertEquals(true, comparePropWithConditionValue(this.semverProp, null, "1", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.semverProp, null, "1.1", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.semverProp, null, "1.1.1", ConditionOperator.Equal))
    }

    @Test
    fun shouldCompareTimestamp() {
        assertEquals(true, comparePropWithConditionValue(this.timeProp, null, "2011-10-05T14:48:00.000Z", ConditionOperator.Equal))
        assertEquals(false, comparePropWithConditionValue(this.timeProp, null, "2011-10-05T14:49:00.000Z", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.timeProp, null, "2011-10-05T14:47:00.000Z", ConditionOperator.GreaterThanOrEqual))
        assertEquals(true, comparePropWithConditionValue(this.timeProp, null, "2011-10-05T14:49:00.000Z", ConditionOperator.LessThanOrEqual))
    }

    @Test
    fun shouldCompareBoolean() {
        assertEquals(true, comparePropWithConditionValue(this.boolProp, null, "false", ConditionOperator.Equal))
        assertEquals(true, comparePropWithConditionValue(this.boolProp, null, "true", ConditionOperator.NotEqual))
    }

    @Test
    fun shouldParseStringToBoolean() {
        assertEquals(false, parseStringToBoolean("false"))
        assertEquals(false, parseStringToBoolean("False"))
        assertEquals(false, parseStringToBoolean("FALSE"))
        assertEquals(false, parseStringToBoolean("No"))
        assertEquals(false, parseStringToBoolean("nil"))
        assertEquals(false, parseStringToBoolean("off"))
        assertEquals(false, parseStringToBoolean("off"))
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
