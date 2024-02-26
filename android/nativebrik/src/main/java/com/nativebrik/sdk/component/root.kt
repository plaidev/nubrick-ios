package com.nativebrik.sdk.component

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.component.provider.container.ContainerProvider
import com.nativebrik.sdk.component.provider.data.PageDataProvider
import com.nativebrik.sdk.component.provider.event.EventListenerProvider
import com.nativebrik.sdk.component.provider.pageblock.PageBlockData
import com.nativebrik.sdk.component.provider.pageblock.PageBlockProvider
import com.nativebrik.sdk.component.renderer.ModalBottomSheetBackHandler
import com.nativebrik.sdk.component.renderer.NavigationHeader
import com.nativebrik.sdk.component.renderer.Page
import com.nativebrik.sdk.component.renderer.WebViewPage
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.PageKind
import com.nativebrik.sdk.schema.Property
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import com.nativebrik.sdk.schema.UIPageBlock
import com.nativebrik.sdk.schema.UIRootBlock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class RootViewModel: ViewModel {
    private val root: UIRootBlock
    private val pages: List<UIPageBlock>
    private val context: Context
    val displayedPageBlock = mutableStateOf<PageBlockData?>(null)
    val modalStack = mutableStateOf<List<PageBlockData>>(listOf())
    val displayedModalIndex = mutableIntStateOf(-1)
    val modalVisibility = mutableStateOf(false)
    val webviewUrl = mutableStateOf("")
    private val onDismiss: ((root: UIRootBlock) -> Unit)
    private val scope: CoroutineScope
    @OptIn(ExperimentalMaterial3Api::class)
    private val sheetState: SheetState

    @OptIn(ExperimentalMaterial3Api::class)
    constructor(
        root: UIRootBlock,
        scope: CoroutineScope,
        sheetState: SheetState,
        onDismiss: ((root: UIRootBlock) -> Unit) = {},
        context: Context,
    ) {
        this.context = context
        this.root = root
        this.onDismiss = onDismiss
        this.scope = scope
        this.sheetState = sheetState

        val pages: List<UIPageBlock> = root.data?.pages ?: emptyList()
        this.pages = pages

        val trigger = pages.firstOrNull {
            it.data?.kind == PageKind.TRIGGER
        }
        if (trigger == null) {
            onDismiss(root)
            return
        }
        val destId = trigger.data?.triggerSetting?.onTrigger?.destinationPageId
        if (destId == null) {
            onDismiss(root)
            return
        }
        this.render(destId)
    }

    fun handleUIEvent(it: UIBlockEventDispatcher) {
        val destId = it.destinationPageId ?: ""
        val deepLink = it.deepLink ?: ""
        if (destId.isNotEmpty()) {
            this.render(destId)
        } else if (deepLink.isNotEmpty()) {
            this.openDeepLink(deepLink)
        }
    }

    private fun openDeepLink(link: String) {
        val data = Uri.parse(link) ?: return
        val intent = Intent(Intent.ACTION_VIEW).apply {
            this.data = data
        }
        this.context.startActivity(intent)
    }

    private fun render(destId: String, properties: List<Property>? = null) {
        val destBlock = this.pages.firstOrNull {
            it.id == destId
        }
        if (destBlock == null) {
            this.dismiss()
            return
        }

        if (destBlock.data?.kind == PageKind.DISMISSED) {
            this.dismiss()
            return
        }

        if (destBlock.data?.kind == PageKind.WEBVIEW_MODAL) {
            this.webviewUrl.value = destBlock.data?.webviewUrl ?: ""
            return
        }

        if (destBlock.data?.kind == PageKind.MODAL) {
            val index = this.modalStack.value.indexOfFirst {
                it.block.id == destId
            }
            if (index > 0) {
                // if it's already in modal stack, jump to the target stack
                this.displayedModalIndex.intValue = index
                return
            }

            val modalStack = mutableListOf<PageBlockData>()
            modalStack.addAll(this.modalStack.value)
            modalStack.add(PageBlockData(destBlock, properties))
            this.modalStack.value = modalStack
            this.displayedModalIndex.intValue = modalStack.size - 1
            this.modalVisibility.value = true
            return
        }

        this.dismiss()
        this.displayedPageBlock.value = PageBlockData(destBlock, properties)
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
        this.scope.launch { self.sheetState.hide() }.invokeOnCompletion { self.handleModalDismiss() }
    }

    @OptIn(ExperimentalMaterial3Api::class)
    private fun dismiss() {
        this.displayedModalIndex.intValue = 0;
        val self = this
        if (self.sheetState.currentValue == SheetValue.Expanded && self.sheetState.hasPartiallyExpandedState) {
            this.scope.launch { self.sheetState.partialExpand() }
        } else { // Is expanded without collapsed state or is collapsed.
            this.scope.launch { self.sheetState.hide() }.invokeOnCompletion { self.handleModalDismiss() }
        }
    }

    fun handleModalDismiss() {
        this.webviewUrl.value = ""
        this.modalStack.value = emptyList()
        this.displayedModalIndex.intValue = -1
        this.modalVisibility.value = false
        this.onDismiss(this.root)
    }

    fun handleWebviewDismiss() {
        this.webviewUrl.value = ""
    }
}

@Composable
internal fun ModalPage(
    container: Container,
    blockData: PageBlockData,
    modifier: Modifier = Modifier
) {
    PageBlockProvider(
        blockData,
    ) {
        PageDataProvider(container = container, request = blockData.block.data?.httpRequest) {
            Page(block = blockData.block, modifier)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun Root(
    modifier: Modifier = Modifier,
    container: Container,
    root: UIRootBlock,
    embeddingVisibility: Boolean = true,
    onDismiss: ((root: UIRootBlock) -> Unit) = {},
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    val webviewSheetState = rememberModalBottomSheetState()
    val sheetState = rememberModalBottomSheetState()
    val scope = rememberCoroutineScope()
    val viewModel = remember(root, sheetState, scope, onDismiss, context) {
        RootViewModel(root, scope, sheetState, onDismiss, context)
    }
    val bottomSheetProps = remember {
        ModalBottomSheetDefaults.properties(shouldDismissOnBackPress = false)
    }
    val listener = remember<(event: UIBlockEventDispatcher) -> Unit>(key1 = viewModel) {
        return@remember {
            viewModel.handleUIEvent(it)
        }
    }

    val displayedPageBlock = viewModel.displayedPageBlock.value
    val modalStack = viewModel.modalStack.value

    ContainerProvider(container = container) {
        EventListenerProvider(listener = listener) {
            Box {
                if (embeddingVisibility && displayedPageBlock != null) {
                    AnimatedContent(
                        targetState = displayedPageBlock,
                        transitionSpec = {
                            fadeIn() togetherWith fadeOut()
                        },
                        label = "Embedding",
                    ) {
                        PageBlockProvider(it) {
                            PageDataProvider(container = container, request = it.block.data?.httpRequest) {
                                Page(block = it.block, modifier)
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
                            viewModel.handleModalDismiss()
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
                                NavigationHeader(it, stack.block, onClose = { viewModel.close() }, onBack = { viewModel.back() })
                                ModalPage(
                                    container = container,
                                    blockData = stack,
                                )
                            }
                        }
                    }
                }
                if (viewModel.webviewUrl.value.isNotEmpty()) {
                    ModalBottomSheet(
                        sheetState = webviewSheetState,
                        onDismissRequest = {
                            viewModel.handleWebviewDismiss()
                        }) {
                        Box(
                            Modifier.verticalScroll(scrollState, true)
                        ) {
                            WebViewPage(url = viewModel.webviewUrl.value, modifier = Modifier.defaultMinSize(minHeight = 200f.dp))
                        }
                    }
                }
            }
        }

    }

}
