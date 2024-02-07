package com.nativebrik.sdk.component.renderer

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.UIBlock

@Composable
fun Block(block: UIBlock, modifier: Modifier = Modifier) {
    return when (block) {
        is UIBlock.UnionUIFlexContainerBlock -> Flex(block = block.data, modifier) {
            block.data.data?.children?.map {
                Block(block = it)
            }
        }
        is UIBlock.UnionUIImageBlock -> Image(block = block.data, modifier)
        is UIBlock.UnionUITextBlock -> Text(block = block.data, modifier)
        else -> Unit
    }
}