package com.nativebrik.sdk.component.provider.data

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.component.provider.pageblock.PageBlockContext
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.ApiHttpRequest
import kotlinx.serialization.json.JsonElement

private var LocalData = compositionLocalOf<DataState> {
    error("LocalData is not found")
}

internal data class DataState(
    val loading: Boolean,
    val data: JsonElement
)

internal object DataContext {
    /**
     * Retrieves the current [DataState] at the call site's position in the hierarchy.
     */
    val state: DataState
        @Composable
        @ReadOnlyComposable
        get() = LocalData.current
}

@Composable
internal fun rememberPageState(
    container: Container,
    request: ApiHttpRequest?,
): DataState {
    val pageBlock = PageBlockContext.value
    var state: DataState by remember {
        mutableStateOf(DataState(
            loading = true,
            container.createVariableForTemplate(
                properties = pageBlock.toProperties()
            )
        ))
    }
    LaunchedEffect("key") {
        if (request == null) {
            state = state.copy(loading = false)
            return@LaunchedEffect
        }
        state = state.copy(loading = true)
        container.sendHttpRequest(
            request, container.createVariableForTemplate(properties = pageBlock.toProperties())
        ).onSuccess {
            state = state.copy(
                loading = false,
                data = container.createVariableForTemplate(it, properties = pageBlock.toProperties())
            )
        }.onFailure {
            state = state.copy(loading = false)
        }
    }
    return state
}

@Composable
internal fun rememberNestedDataState(
    data: JsonElement,
): DataState {
    val pageBlock = PageBlockContext.value
    val container = ContainerContext.value
    val parentData by rememberUpdatedState(newValue = DataContext.state)
    return remember(parentData, data) {
        DataState(
            loading = parentData.loading,
            data = container.createVariableForTemplate(data = data, properties = pageBlock.toProperties())
        )
    }
}

@Composable
internal fun NestedDataProvider(
    data: JsonElement,
    content: @Composable() () -> Unit
) {
    val state = rememberNestedDataState(data)
    CompositionLocalProvider(
        LocalData provides state
    ) {
        content()
    }
}

@Composable
internal fun PageDataProvider(
    container: Container,
    request: ApiHttpRequest?,
    content: @Composable() () -> Unit
) {
    val state = rememberPageState(container, request)
    CompositionLocalProvider(
        LocalData provides state
    ) {
        content()
    }
}
