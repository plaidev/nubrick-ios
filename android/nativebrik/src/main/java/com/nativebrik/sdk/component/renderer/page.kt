package com.nativebrik.sdk.component.renderer

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.UIPageBlock

@Composable
internal fun Page(
    block: UIPageBlock,
    modifier: Modifier = Modifier,
) {
    val renderAs = block.data?.renderAs ?: return Unit
    Block(block = renderAs, modifier)
}
