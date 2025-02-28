package com.nativebrik.flutter.nativebrik_bridge

import kotlin.test.assertEquals
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito
import com.nativebrik.sdk.VERSION

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class NativebrikBridgePluginTest {
    @Test
    fun onMethodCall_getNativebrikSDKVersion_returnsExpectedValue() {
        val plugin = NativebrikBridgePlugin()

        val call = MethodCall("getNativebrikSDKVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(VERSION)
    }

    @Test
    fun parseStackTraceElements_should_work() {
        val stackTraces = parseStackTraceElements(
            "#0      NativebrikDispatcher.dispatch (package:nativebrik_bridge/dispatcher.dart:10:5)\n" +
            "#1      _MyAppState.build.<anonymous closure> (package:nativebrik_bridge_example/main.dart:91:42)"
        )

        val expected = listOf(
            StackTraceElement("NativebrikDispatcher", "dispatch", "package:nativebrik_bridge/dispatcher.dart", 10),
            StackTraceElement("unknown", "unknown", "package:nativebrik_bridge_example/main.dart", 91)
        )

        assertEquals(expected.size, stackTraces.size)
        assertEquals(expected[0].fileName, stackTraces[0].fileName)
        assertEquals(expected[0].lineNumber, stackTraces[0].lineNumber)
        assertEquals(expected[1].fileName, stackTraces[1].fileName)
        assertEquals(expected[1].lineNumber, stackTraces[1].lineNumber)
    }

}
