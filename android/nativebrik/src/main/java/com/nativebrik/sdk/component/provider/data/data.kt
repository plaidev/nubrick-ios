package com.nativebrik.sdk.component.provider.data

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.ApiHttpRequest
import kotlinx.serialization.json.JsonElement

var LocalData = compositionLocalOf<DataState> {
    error("LocalData is not found")
}

data class DataState(
    val loading: Boolean,
    val data: JsonElement? = null
)

@Composable
fun rememberRootState(
    container: Container,
    request: ApiHttpRequest?,
): DataState {
    var state: DataState by remember { mutableStateOf(DataState(loading = true)) }
    LaunchedEffect("key") {
        if (request == null) {
            state = DataState(loading = false)
            return@LaunchedEffect
        }
        state = DataState(loading = true)
        container.sendHttpRequest(request).onSuccess {
            state = DataState(loading = true)
        }.onFailure {
            state = DataState(loading = false)
        }
    }
    return remember(state) {
        state
    }
}


@Composable
fun DataProvider(
    container: Container,
    request: ApiHttpRequest?,
    content: @Composable() () -> Unit
) {
    val rootState = rememberRootState(container, request)
    CompositionLocalProvider(
        LocalData provides rootState
    ) {
        content()
    }
}