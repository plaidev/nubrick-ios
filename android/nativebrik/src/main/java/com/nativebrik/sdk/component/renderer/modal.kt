package com.nativebrik.sdk.component.renderer

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import com.nativebrik.sdk.schema.UIPageBlock


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Modal(block: UIPageBlock, onDismiss: () -> Unit , content: @Composable() () -> Unit) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        content()
    }
}
