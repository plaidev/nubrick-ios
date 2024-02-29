package com.nativebrik.sdk.data.user


import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.nativebrik.sdk.VERSION
import com.nativebrik.sdk.schema.BuiltinUserProperty
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class UserAndroidTest {
    @Test
    fun shouldInitiateUser() {
        // Context of the app under test.
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        val user = NativebrikUser(context = appContext, 0)
        Assert.assertEquals(true, user.id.count() == 36)
        Assert.assertEquals(0.22964408192413588, user.getNormalizedUserRnd(0), 0.0001)

        val propSeed = 10
        val props = user.toUserProperties(propSeed)
        val sdkVersion = props.firstOrNull {
            it.name == BuiltinUserProperty.sdkVersion.toString()
        }
        Assert.assertEquals(VERSION, sdkVersion?.value)

        val osVersion = props.firstOrNull {
            it.name == BuiltinUserProperty.osVersion.toString()
        }
        Assert.assertEquals(Build.VERSION.SDK_INT.toString(), osVersion?.value)

        val osName = props.firstOrNull {
            it.name == BuiltinUserProperty.osName.toString()
        }
        Assert.assertEquals("Android", osName?.value)

        val rnd = props.first {
            it.name == BuiltinUserProperty.userRnd.toString()
        }
        Assert.assertEquals(user.getNormalizedUserRnd(propSeed), rnd.value.toDouble(), 0.0001)
    }
}
