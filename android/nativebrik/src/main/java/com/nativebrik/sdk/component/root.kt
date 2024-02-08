package com.nativebrik.sdk.component

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.component.provider.data.DataProvider
import com.nativebrik.sdk.component.provider.event.EventListenerProvider
import com.nativebrik.sdk.component.renderer.Modal
import com.nativebrik.sdk.component.renderer.Page
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.PageKind
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import com.nativebrik.sdk.schema.UIPageBlock
import com.nativebrik.sdk.schema.UIRootBlock

class RootViewModel: ViewModel {
    private val pages: List<UIPageBlock>;
    val displayedPageBlock = mutableStateOf<UIPageBlock?>(null)
    val modalStack = mutableStateOf<List<UIPageBlock>>(listOf())

    constructor(root: UIRootBlock) {
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
            this.modalStack.value = emptyList()
            return
        }

        if (destBlock.data?.kind == PageKind.WEBVIEW_MODAL) {
            return
        }

        if (destBlock.data?.kind == PageKind.MODAL) {
            val modalStack = mutableListOf<UIPageBlock>()
            modalStack.addAll(this.modalStack.value)
            modalStack.add(destBlock)
            this.modalStack.value = modalStack
            return
        }
        this.modalStack.value = emptyList()
        this.displayedPageBlock.value = destBlock
    }

    fun dismiss() {
        this.modalStack.value = emptyList()
    }
}

@Composable
fun Root(container: Container, root: UIRootBlock, modifier: Modifier = Modifier) {
    val viewModel = remember {
        RootViewModel(root)
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
            DataProvider(container = container, request = displayedPageBlock.data?.httpRequest) {
                EventListenerProvider(listener = listener) {
                    Page(block = displayedPageBlock, modifier)
                }
            }
        }
        if (modalStack.isNotEmpty()) {
            val latest = modalStack.last()
            Modal(block = latest, onDismiss = { viewModel.dismiss() }) {
                EventListenerProvider(listener = listener) {
                    Page(block = latest, modifier)
                }
            }
        }
    }
}
