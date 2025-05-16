package com.nativebrik.sdk.component

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetState
import androidx.compose.material3.SheetValue
import androidx.compose.runtime.mutableStateOf
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
    private val scope: CoroutineScope,
    private val onDismiss: () -> Unit,
) {
    var modalState = mutableStateOf(ModalState())
        private set

    fun show(
        block: PageBlockData,
        modalPresentationStyle: ModalPresentationStyle,
        modalScreenSize: ModalScreenSize,
    ) {
        modalState.value = modalState.value.copy(
            modalStack = modalState.value.modalStack + block,
            displayedModalIndex = modalState.value.modalStack.size,
            modalVisibility = true,
            modalPresentationStyle = modalPresentationStyle,
            modalScreenSize = modalScreenSize
        )
    }

    fun backTo(index: Int) {
        if (index < 0 || index >= modalState.value.modalStack.size) {
            return
        }
        modalState.value = modalState.value.copy(displayedModalIndex = index)
    }

    fun back() {
        val index = modalState.value.displayedModalIndex
        if (index <= 0) {
            // if the stack size is zero, just dismiss it. maybe unreachable
            dismiss()
            return
        }
        // pop the stack
        modalState.value = modalState.value.copy(displayedModalIndex = index - 1)
    }

    fun close() {
        modalState.value = modalState.value.copy(displayedModalIndex = 0)
        scope.launch { sheetState.hide() }
            .invokeOnCompletion { dismiss() }
    }

    fun dismiss() {
        modalState.value = ModalState() // reset the modal state
        scope.launch {
            if (sheetState.currentValue == SheetValue.Expanded && sheetState.hasPartiallyExpandedState) {
                sheetState.partialExpand()
            } else {
                // Is expanded without collapsed state or is collapsed.
                sheetState.hide()
                onDismiss()
            }
        }
    }
}
