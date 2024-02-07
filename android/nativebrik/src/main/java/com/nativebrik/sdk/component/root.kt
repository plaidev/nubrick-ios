package com.nativebrik.sdk.component

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.component.renderer.Page
import com.nativebrik.sdk.schema.PageKind
import com.nativebrik.sdk.schema.UIPageBlock
import com.nativebrik.sdk.schema.UIRootBlock

@Composable
fun Root(root: UIRootBlock, modifier: Modifier = Modifier) {
    val pages: List<UIPageBlock> = root.data?.pages ?: emptyList()
    val trigger = pages.first {
        it.data?.kind == PageKind.TRIGGER
    }

    val destId = trigger.data?.triggerSetting?.onTrigger?.destinationPageId ?: return Unit
    val destBlock = pages.first {
        it.id == destId
    }

    if (destBlock.data?.kind == PageKind.DISMISSED) {
        return Unit
    }

    if (destBlock.data?.kind == PageKind.WEBVIEW_MODAL) {
        return Unit
    }

    if (destBlock.data?.kind == PageKind.MODAL) {
        return Unit
    }
    
    Page(block = destBlock, modifier)
}
