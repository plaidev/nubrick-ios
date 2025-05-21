package com.nativebrik.sdk.component.renderer

import android.os.Build
import android.window.OnBackInvokedDispatcher
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.nativebrik.sdk.schema.UIPageBlock

@Composable
internal fun ModalBottomSheetBackHandler(handler: () -> Unit) {
    val view = rememberUpdatedState(LocalView.current)
    DisposableEffect(handler) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            view.value.findOnBackInvokedDispatcher()?.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_OVERLAY,
                handler
            )
        }
        onDispose {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                view.value.findOnBackInvokedDispatcher()?.unregisterOnBackInvokedCallback(handler)
            }
        }
    }
}

@Composable
internal fun NavigationHeader(
    index: Int,
    block: UIPageBlock,
    onClose: () -> Unit,
    onBack: () -> Unit,
    isFullscreen: Boolean,
) {
    val visibility = block.data?.modalNavigationBackButton?.visible ?: true
    val insetTop = with(LocalDensity.current) {
        WindowInsets.statusBars.getTop(this).toDp()
    }

    Box(
        modifier = Modifier
            .zIndex(10f)
            .offset(y = if (isFullscreen) insetTop else 0.dp)
    ) {
        if (visibility) {
            if (index > 0) {
                IconButton(onClick = { onBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Outlined.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            } else {
                IconButton(onClick = { onClose() }) {
                    Icon(imageVector = Icons.Outlined.Close, contentDescription = "Close")
                }
            }
        }
    }
}
