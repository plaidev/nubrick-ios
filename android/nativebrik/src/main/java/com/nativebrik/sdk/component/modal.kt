package com.nativebrik.sdk.component

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetState
import androidx.compose.material3.SheetValue
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nativebrik.sdk.component.provider.pageblock.PageBlockData
import com.nativebrik.sdk.schema.ModalPresentationStyle
import com.nativebrik.sdk.schema.ModalScreenSize
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class ModalState(
    val modalStack: List<PageBlockData> = emptyList(),
    val displayedModalIndex: Int = -1,
    val modalVisibility: Boolean = false,
    val modalPresentationStyle: ModalPresentationStyle = ModalPresentationStyle.UNKNOWN,
    val modalScreenSize: ModalScreenSize = ModalScreenSize.UNKNOWN,
)

@OptIn(ExperimentalMaterial3Api::class)
internal class ModalViewModel(
    private val sheetState: SheetState,
    // NOTE: This is a workaround for the issue where the skipPartiallyExpanded can not be conditionally set.
    private val largeSheetState: SheetState,
    private val scope: CoroutineScope,
    private val onDismiss: () -> Unit,
) {
    var modalState by mutableStateOf(ModalState())
        private set

    fun show(
        block: PageBlockData,
        modalPresentationStyle: ModalPresentationStyle,
        modalScreenSize: ModalScreenSize,
    ) {
        modalState = modalState.copy(
            modalStack = modalState.modalStack + block,
            displayedModalIndex = modalState.modalStack.size,
            modalVisibility = true,
            modalPresentationStyle = if (modalState.modalVisibility) modalState.modalPresentationStyle else modalPresentationStyle,
            modalScreenSize = if (modalState.modalVisibility) modalState.modalScreenSize else modalScreenSize
        )
    }

    fun backTo(index: Int) {
        if (index < 0 || index >= modalState.modalStack.size) {
            return
        }
        modalState = modalState.copy(displayedModalIndex = index)
    }

    fun back() {
        val index = modalState.displayedModalIndex
        if (index <= 0) {
            close()
            return
        }
        // pop the stack
        modalState = modalState.copy(displayedModalIndex = index - 1)
    }

    fun close() {
        scope.launch {
            if (sheetState.currentValue == SheetValue.Expanded && sheetState.hasPartiallyExpandedState) {
                // shrink form large to medium
                sheetState.partialExpand()
                return@launch
            }

            // hide and reset state
            sheetState.hide()
            largeSheetState.hide()
            modalState = ModalState()
            onDismiss()
        }
    }
}
