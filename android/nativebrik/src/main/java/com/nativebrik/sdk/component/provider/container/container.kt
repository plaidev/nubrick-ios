package com.nativebrik.sdk.component.provider.container

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import com.nativebrik.sdk.data.Container


internal var LocalContainer = compositionLocalOf<Container> {
    error("LocalContainer is not found")
}

internal object ContainerContext {
    /**
     * Retrieves the current [Container] at the call site's position in the hierarchy.
     */
    val value: Container
        @Composable
        @ReadOnlyComposable
        get() = LocalContainer.current
}

@Composable
internal fun ContainerProvider(
    container: Container,
    content: @Composable() () -> Unit,
) {
    CompositionLocalProvider(
        LocalContainer provides container
    ) {
        content()
    }
}
