package com.nativebrik.sdk.component

import SetDialogDestinationToEdgeToEdge
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalBottomSheetDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.net.toUri
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.Event
import com.nativebrik.sdk.EventProperty
import com.nativebrik.sdk.EventPropertyType
import com.nativebrik.sdk.component.bridge.UIBlockEventBridgeCollector
import com.nativebrik.sdk.component.bridge.UIBlockEventBridgeViewModel
import com.nativebrik.sdk.component.provider.container.ContainerProvider
import com.nativebrik.sdk.component.provider.data.PageDataProvider
import com.nativebrik.sdk.component.provider.event.EventListenerProvider
import com.nativebrik.sdk.component.provider.pageblock.PageBlockData
import com.nativebrik.sdk.component.provider.pageblock.PageBlockProvider
import com.nativebrik.sdk.component.renderer.MODAL_NAV_HEADER_HEIGHT
import com.nativebrik.sdk.component.renderer.ModalBottomSheetBackHandler
import com.nativebrik.sdk.component.renderer.NavigationHeader
import com.nativebrik.sdk.component.renderer.Page
import com.nativebrik.sdk.component.renderer.WebViewPage
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.ModalPresentationStyle
import com.nativebrik.sdk.schema.ModalScreenSize
import com.nativebrik.sdk.schema.PageKind
import com.nativebrik.sdk.schema.Property
import com.nativebrik.sdk.schema.PropertyType
import com.nativebrik.sdk.schema.UIBlockEventDispatcher
import com.nativebrik.sdk.schema.UIPageBlock
import com.nativebrik.sdk.schema.UIRootBlock
import com.nativebrik.sdk.template.compile
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.serialization.json.JsonElement

private fun parseUIEventToEvent(event: UIBlockEventDispatcher): Event {
    return Event(
        name = event.name,
        deepLink = event.deepLink,
        payload = event.payload?.map { p ->
            EventProperty(
                name = p.name ?: "",
                value = p.value ?: "",
                type = when (p.ptype) {
                    PropertyType.INTEGER -> EventPropertyType.INTEGER
                    PropertyType.STRING -> EventPropertyType.STRING
                    PropertyType.TIMESTAMPZ -> EventPropertyType.TIMESTAMPZ
                    else -> EventPropertyType.UNKNOWN
                }
            )
        }
    )
}

internal class RootViewModel(
    private val root: UIRootBlock,
    private val modalViewModel: ModalViewModel,
    private val onNextTooltip: ((pageId: String) -> Unit) = {},
    private val onDismiss: ((root: UIRootBlock) -> Unit) = {},
    private val onOpenDeepLink: ((link: String) -> Unit) = {},
) : ViewModel() {
    private val pages: List<UIPageBlock> = root.data?.pages ?: emptyList()
    val displayedPageBlock = mutableStateOf<PageBlockData?>(null)
    val webviewUrl = mutableStateOf("")

    // We use them for sdk bridge between flutter <-> android.
    val currentPageBlock = mutableStateOf<UIPageBlock?>(null)
    var currentTooltipAnchorId = mutableStateOf("")

    fun initialize() {
        val trigger = pages.firstOrNull {
            it.data?.kind == PageKind.TRIGGER
        } ?: run {
            onDismiss(root)
            return
        }

        val destId = trigger.data?.triggerSetting?.onTrigger?.destinationPageId
        if (destId == null) {
            onDismiss(root)
            return
        }

        render(destId)
    }

    fun handleNavigate(event: UIBlockEventDispatcher, data: JsonElement) {
        val deepLink = event.deepLink?.let { compile(it, data) } ?: ""
        if (deepLink.isNotEmpty()) {
            onOpenDeepLink(deepLink)
        }

        val destId = event.destinationPageId ?: ""
        if (destId.isNotEmpty()) {
            this.render(destId)
        }
    }

    private fun render(destId: String, properties: List<Property>? = null) {
        val destBlock = this.pages.firstOrNull {
            it.id == destId
        }
        if (destBlock == null) {
            return
        }

        this.currentPageBlock.value = destBlock

        if (destBlock.data?.kind == PageKind.DISMISSED) {
            this.dismiss()
            return
        }

        if (destBlock.data?.kind == PageKind.WEBVIEW_MODAL) {
            this.webviewUrl.value = destBlock.data.webviewUrl ?: ""
            return
        }

        if (destBlock.data?.kind == PageKind.TOOLTIP) {
            val anchorId = destBlock.data.tooltipAnchor ?: ""
            if (this.currentTooltipAnchorId.value != anchorId) {
                onNextTooltip(destId)
            }
            this.currentTooltipAnchorId.value = anchorId
        }

        if (destBlock.data?.kind == PageKind.MODAL) {
            val index = modalViewModel.modalState.modalStack.indexOfFirst {
                it.block.id == destId
            }
            if (index > 0) {
                // if it's already in modal stack, jump to the target stack
                modalViewModel.backTo(index)
                return
            }

            modalViewModel.show(
                block = PageBlockData(destBlock, properties),
                modalPresentationStyle = destBlock.data.modalPresentationStyle
                    ?: ModalPresentationStyle.UNKNOWN,
                modalScreenSize = destBlock.data.modalScreenSize ?: ModalScreenSize.UNKNOWN
            )
            return
        }

        // Before displaying the page, we close displayed modals. but never emit dismiss event.
        modalViewModel.close(forceReset = true, emitDispatch = false)
        this.displayedPageBlock.value = PageBlockData(destBlock, properties)
    }

    private fun dismiss(emitDispatch: Boolean = true) {
        this.currentPageBlock.value = null
        modalViewModel.close(forceReset = true, emitDispatch = emitDispatch)
    }

    fun handleWebviewDismiss() {
        this.webviewUrl.value = ""
    }
}

@DelicateCoroutinesApi
@Composable
internal fun ModalPage(
    container: Container,
    blockData: PageBlockData,
    eventBridge: UIBlockEventBridgeViewModel?,
    currentPageBlock: UIPageBlock?,
    modifier: Modifier = Modifier,
    isFullscreen: Boolean,
) {
    val insetTop = if (blockData.block.data?.modalRespectSafeArea == true) {
        if (isFullscreen) {
            with(LocalDensity.current) {
                WindowInsets.statusBars.getTop(this)
                    .toDp() + MODAL_NAV_HEADER_HEIGHT // status bar + nav header height
            }
        } else {
            MODAL_NAV_HEADER_HEIGHT
        }
    } else {
        0.dp
    }

    PageBlockProvider(
        blockData,
    ) {
        PageDataProvider(container = container, request = blockData.block.data?.httpRequest) {
            UIBlockEventBridgeCollector(
                events = eventBridge?.events,
                isCurrentPage = blockData.block.id == currentPageBlock?.id
            )
            Page(block = blockData.block, modifier, insetTop)
        }
    }
}

@DelicateCoroutinesApi
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun Root(
    modifier: Modifier = Modifier,
    container: Container,
    root: UIRootBlock,
    embeddingVisibility: Boolean = true,
    onEvent: (event: Event) -> Unit = {},
    onNextTooltip: (pageId: String) -> Unit = {},
    onDismiss: ((root: UIRootBlock) -> Unit) = {},
    eventBridge: UIBlockEventBridgeViewModel? = null,
) {
    val sheetState = rememberModalBottomSheetState()
    val largeSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val modalViewModel = remember(sheetState, scope) {
        ModalViewModel(sheetState, largeSheetState, scope, onDismiss = { onDismiss(root) })
    }
    val context = LocalContext.current
    val viewModel = remember(root, modalViewModel, onDismiss, context) {
        RootViewModel(
            root,
            modalViewModel,
            onNextTooltip,
            onDismiss,
            onOpenDeepLink = { link ->
                val intent = Intent(Intent.ACTION_VIEW, link.toUri()).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try {
                    context.startActivity(intent)
                } catch (_: Throwable) {
                }
            })
    }
    LaunchedEffect(Unit) {
        viewModel.initialize()
    }
    val bottomSheetProps = remember {
        ModalBottomSheetDefaults.properties(shouldDismissOnBackPress = false)
    }
    val listener = remember(viewModel, onEvent, container) {
        { event: UIBlockEventDispatcher, data: JsonElement ->
            viewModel.handleNavigate(event, data)

            val e = parseUIEventToEvent(event)
            onEvent(e)
            container.handleEvent(e)
        }
    }

    val currentPageBlock = viewModel.currentPageBlock.value
    val displayedPageBlock = viewModel.displayedPageBlock.value
    val modalState = modalViewModel.modalState

    ContainerProvider(container = container) {
        EventListenerProvider(listener = listener) {
            Box(Modifier.fillMaxSize()) {
                if (embeddingVisibility && displayedPageBlock != null) {
                    AnimatedContent(
                        targetState = displayedPageBlock,
                        transitionSpec = {
                            fadeIn() togetherWith fadeOut()
                        },
                        label = "Embedding",
                        modifier = Modifier.fillMaxSize()
                    ) {
                        PageBlockProvider(it) {
                            PageDataProvider(
                                container = container,
                                request = it.block.data?.httpRequest
                            ) {
                                UIBlockEventBridgeCollector(
                                    events = eventBridge?.events,
                                    isCurrentPage = it.block.id == currentPageBlock?.id
                                )
                                Page(block = it.block)
                            }
                        }
                    }
                }

                if (modalState.modalVisibility) {
                    BackHandler(true) {
                        modalViewModel.back()
                    }
                    val isLarge =
                        modalState.modalPresentationStyle == ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_FULL_SCREEN
                                || modalState.modalScreenSize == ModalScreenSize.LARGE
                    val insetTop = with(LocalDensity.current) {
                        WindowInsets.statusBars.getTop(this).toDp()
                    }
                    ModalBottomSheet(
                        sheetState = if (isLarge) largeSheetState else sheetState,
                        onDismissRequest = {
                            modalViewModel.close()
                        },
                        properties = bottomSheetProps,
                        dragHandle = {},
                        windowInsets = WindowInsets(0, 0, 0, 0),
                        shape = RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp),
                    ) {
                        ModalBottomSheetBackHandler {
                            modalViewModel.back()
                        }
                        Column(
                            modifier = if (modalState.modalPresentationStyle == ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_FULL_SCREEN) {
                                Modifier.fillMaxSize()
                            } else {
                                if (modalState.modalScreenSize == ModalScreenSize.MEDIUM) {
                                    Modifier.height(LocalConfiguration.current.screenHeightDp.dp * 0.5f)
                                } else {
                                    Modifier.height(
                                        LocalConfiguration.current.screenHeightDp.dp - insetTop
                                    )
                                }
                            }
                        ) {
                            AnimatedContent(
                                targetState = modalState.displayedModalIndex,
                                transitionSpec = {
                                    if (targetState > initialState) {
                                        slideInHorizontally { it } togetherWith slideOutHorizontally { -it } + fadeOut()
                                    } else {
                                        slideInHorizontally { -it } togetherWith slideOutHorizontally { it } + fadeOut()
                                    }
                                },
                                label = "Bottom Sheet"
                            ) {
                                val stack = modalState.modalStack[it]
                                val isFullscreen =
                                    modalState.modalPresentationStyle == ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_FULL_SCREEN
                                NavigationHeader(
                                    it,
                                    stack.block,
                                    onClose = { modalViewModel.close() },
                                    onBack = { modalViewModel.back() },
                                    isFullscreen,
                                )
                                ModalPage(
                                    container = container,
                                    blockData = stack,
                                    eventBridge = eventBridge,
                                    currentPageBlock = currentPageBlock,
                                    isFullscreen = isFullscreen,
                                )
                            }
                        }
                    }
                }

                if (viewModel.webviewUrl.value.isNotEmpty()) {
                    Dialog(
                        properties = DialogProperties(
                            usePlatformDefaultWidth = true,
                            decorFitsSystemWindows = false
                        ),
                        onDismissRequest = {}
                    ) {
                        val statusBarHeight = with(LocalDensity.current) {
                            WindowInsets.statusBars.getTop(this).toDp()
                        }
                        SetDialogDestinationToEdgeToEdge()
                        Box(
                            Modifier
                                .fillMaxSize()
                                .background(Color.LightGray)
                        ) {
                            WebViewPage(
                                url = viewModel.webviewUrl.value,
                                onDismiss = {
                                    viewModel.handleWebviewDismiss()
                                },
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(top = statusBarHeight)
                            )
                        }
                    }
                }
            }
        }
    }
}
