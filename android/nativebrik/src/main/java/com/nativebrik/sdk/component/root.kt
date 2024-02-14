package com.nativebrik.sdk.component

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalBottomSheetDefaults
import androidx.compose.material3.SheetState
import androidx.compose.material3.SheetValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.component.provider.data.PageDataProvider
import com.nativebrik.sdk.component.provider.event.EventListenerProvider
import com.nativebrik.sdk.component.renderer.ModalBottomSheetBackHandler
import com.nativebrik.sdk.component.renderer.NavigationHeader
import com.nativebrik.sdk.component.renderer.Page
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.PageKind
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import com.nativebrik.sdk.schema.UIPageBlock
import com.nativebrik.sdk.schema.UIRootBlock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

class RootViewModel: ViewModel {
    private val pages: List<UIPageBlock>;
    val displayedPageBlock = mutableStateOf<UIPageBlock?>(null)
    val modalStack = mutableStateOf<List<UIPageBlock>>(listOf())
    val displayedModalIndex = mutableIntStateOf(-1)
    val modalVisibility = mutableStateOf(false)
    private val scope: CoroutineScope
    @OptIn(ExperimentalMaterial3Api::class)
    private val sheetState: SheetState

    @OptIn(ExperimentalMaterial3Api::class)
    constructor(root: UIRootBlock, scope: CoroutineScope, sheetState: SheetState) {
        this.scope = scope
        this.sheetState = sheetState

        val pages: List<UIPageBlock> = root.data?.pages ?: emptyList()
        this.pages = pages

        val trigger = pages.firstOrNull {
            it.data?.kind == PageKind.TRIGGER
        } ?: return
        val destId = trigger.data?.triggerSetting?.onTrigger?.destinationPageId ?: return
        this.render(destId)
    }

    fun render(destId: String) {
        val destBlock = this.pages.firstOrNull {
            it.id == destId
        } ?: return

        if (destBlock.data?.kind == PageKind.DISMISSED) {
            this.dismiss()
            return
        }

        if (destBlock.data?.kind == PageKind.WEBVIEW_MODAL) {
            return
        }

        if (destBlock.data?.kind == PageKind.MODAL) {
            val index = this.modalStack.value.indexOfFirst {
                it.id == destId
            }
            if (index > 0) {
                // if it's already in modal stack, jump to the target stack
                this.displayedModalIndex.intValue = index
                return
            }

            val modalStack = mutableListOf<UIPageBlock>()
            modalStack.addAll(this.modalStack.value)
            modalStack.add(destBlock)
            this.modalStack.value = modalStack
            this.displayedModalIndex.intValue = modalStack.size - 1
            this.modalVisibility.value = true
            return
        }

        this.dismiss()
        this.displayedPageBlock.value = destBlock
    }

    fun back() {
        // if the stack size is zero, just dismiss it
        if (this.displayedModalIndex.intValue <= 0) {
            this.dismiss()
            return
        }
        // pop the stack
        this.displayedModalIndex.intValue--;
    }

    @OptIn(ExperimentalMaterial3Api::class)
    fun close() {
        this.displayedModalIndex.intValue = 0;
        val self = this
        this.scope.launch { self.sheetState.hide() }.invokeOnCompletion { self.onModalDismiss() }
    }

    @OptIn(ExperimentalMaterial3Api::class)
    private fun dismiss() {
        this.displayedModalIndex.intValue = 0;
        val self = this
        if (self.sheetState.currentValue == SheetValue.Expanded && self.sheetState.hasPartiallyExpandedState) {
            this.scope.launch { self.sheetState.partialExpand() }
        } else { // Is expanded without collapsed state or is collapsed.
            this.scope.launch { self.sheetState.hide() }.invokeOnCompletion { self.onModalDismiss() }
        }
    }

    fun onModalDismiss() {
        this.modalStack.value = emptyList()
        this.displayedModalIndex.intValue = -1
        this.modalVisibility.value = false
    }
}

@Composable
fun ModalPage(
    container: Container,
    listener: (event: UIBlockEventDispatcher) -> Unit,
    block: UIPageBlock,
    modifier: Modifier = Modifier
) {
    PageDataProvider(container = container, request = block.data?.httpRequest) {
        EventListenerProvider(listener = listener) {
            Page(block = block, modifier)
        }
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Root(container: Container, root: UIRootBlock, modifier: Modifier = Modifier) {
    val sheetState = rememberModalBottomSheetState()
    val scope = rememberCoroutineScope()
    val viewModel = remember(root, sheetState, scope) {
        RootViewModel(root, scope, sheetState)
    }
    val bottomSheetProps = remember {
        ModalBottomSheetDefaults.properties(shouldDismissOnBackPress = false)
    }
    val listener = remember<(event: UIBlockEventDispatcher) -> Unit>(key1 = viewModel) {
        {
            val destId = it.destinationPageId
            if (destId != null) {
                viewModel.render(destId)
            }
        }
    }

    val displayedPageBlock = viewModel.displayedPageBlock.value
    val modalStack = viewModel.modalStack.value

    Box {
        if (displayedPageBlock != null) {
            AnimatedContent(
                targetState = displayedPageBlock,
                transitionSpec = {
                    fadeIn() togetherWith fadeOut()
                },
                label = "Embedding",
            ) {
                PageDataProvider(container = container, request = it.data?.httpRequest) {
                    EventListenerProvider(listener = listener) {
                        Page(block = it, modifier)
                    }
                }
            }
        }
        if (viewModel.modalVisibility.value) {
            BackHandler(true) {
                viewModel.back()
            }
            ModalBottomSheet(
                sheetState = sheetState,
                onDismissRequest = {
                    viewModel.onModalDismiss()
                },
                properties = bottomSheetProps,
            ) {
                ModalBottomSheetBackHandler {
                    viewModel.back()
                }
                Column {
                    AnimatedContent(
                        targetState = viewModel.displayedModalIndex.intValue,
                        transitionSpec = {
                            if (targetState > initialState) {
                                slideInHorizontally { it } togetherWith slideOutHorizontally { -it } + fadeOut()
                            } else {
                                slideInHorizontally { -it } togetherWith slideOutHorizontally { it } + fadeOut()
                            }
                        },
                        label = "Bottom Sheet"
                    ) {
                        val stack = modalStack[it]
                        NavigationHeader(it, stack, onClose = { viewModel.close() } ,onBack = { viewModel.back() })
                        ModalPage(
                            container = container,
                            listener = listener,
                            block = stack,
                        )
                    }
                }
            }
        }
    }
}
