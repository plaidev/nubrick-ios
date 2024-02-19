package com.nativebrik.sdk.component.renderer

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.CollectionKind
import com.nativebrik.sdk.schema.UIBlock

@Composable
internal fun Block(block: UIBlock, modifier: Modifier = Modifier) {
    return when (block) {
        is UIBlock.UnionUIFlexContainerBlock -> Flex(block = block.data, modifier) {
            block.data.data?.children?.map {
                Block(block = it)
            }
        }
        is UIBlock.UnionUIImageBlock -> Image(block = block.data, modifier)
        is UIBlock.UnionUITextBlock -> Text(block = block.data, modifier)
        is UIBlock.UnionUICollectionBlock -> {
            val collection = block.data
            when (collection.data?.kind) {
                CollectionKind.CAROUSEL -> Carousel(block = collection, modifier)
                CollectionKind.GRID -> Grid(block = collection, modifier)
                else -> Grid(block = collection, modifier)
            }
        }
        is UIBlock.UnionUISwitchInputBlock -> Switch(block = block.data, modifier)
        is UIBlock.UnionUITextInputBlock -> TextInput(block = block.data, modifier)
        is UIBlock.UnionUISelectInputBlock -> Select(block = block.data, modifier)
        is UIBlock.UnionUIMultiSelectInputBlock -> MultiSelect(block = block.data, modifier)
        else -> Unit
    }
}
