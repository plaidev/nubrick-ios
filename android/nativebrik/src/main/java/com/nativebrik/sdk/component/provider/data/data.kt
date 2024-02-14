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
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.createVariableForTemplate
import com.nativebrik.sdk.data.mergeVariableForTemplate
import com.nativebrik.sdk.schema.ApiHttpRequest
import kotlinx.serialization.json.JsonElement

internal var LocalData = compositionLocalOf<DataState> {
    error("LocalData is not found")
}

data class DataState(
    val loading: Boolean,
    val data: JsonElement
)

object DataContext {
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
    var state: DataState by remember { mutableStateOf(DataState(loading = true, container.createVariableForTemplate())) }
    LaunchedEffect("key") {
        if (request == null) {
            state = state.copy(loading = false)
            return@LaunchedEffect
        }
        state = state.copy(loading = true)
        container.sendHttpRequest(request, state.data).onSuccess {
            state = state.copy(
                loading = false,
                data = mergeVariableForTemplate(
                    state.data,
                    createVariableForTemplate(data = it),
                )
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
    val parentData by rememberUpdatedState(newValue = DataContext.state)
    return remember(parentData, data) {
        DataState(
            loading = parentData.loading,
            data = mergeVariableForTemplate(
                parentData.data,
                createVariableForTemplate(data = data),
            )
        )
    }
}

@Composable
fun NestedDataProvider(
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
fun PageDataProvider(
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
