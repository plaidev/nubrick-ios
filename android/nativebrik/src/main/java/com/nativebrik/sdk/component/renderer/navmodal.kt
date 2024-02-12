package com.nativebrik.sdk.component.renderer

import android.os.Build
import android.window.OnBackInvokedDispatcher
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalView
import com.nativebrik.sdk.schema.UIPageBlock
@Composable
fun ModalBottomSheetBackHandler(handler: () -> Unit) {
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
fun NavigationHeader(index: Int, block: UIPageBlock, onClose: () -> Unit, onBack: () -> Unit) {
    val visibility = block.data?.modalNavigationBackButton?.visible ?: true
    Box {
        if (visibility) {
            if (index > 0) {
                IconButton(onClick = { onBack() }) {
                    Icon(imageVector = Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                }
            } else {
                IconButton(onClick = { onClose() }) {
                    Icon(imageVector = Icons.Outlined.Close, contentDescription = "Close")
                }
            }
        }
    }
}
