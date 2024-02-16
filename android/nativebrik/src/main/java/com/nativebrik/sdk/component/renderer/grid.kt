package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.nativebrik.sdk.schema.FlexDirection
import com.nativebrik.sdk.schema.UICollectionBlock

@Composable
internal fun Grid(block: UICollectionBlock, modifier: Modifier = Modifier) {
    val children = block.data?.children ?: emptyList()
    val state = rememberLazyGridState(0, 0)
    val padding = parseFramePadding(block.data?.frame)
    val gridSize = block.data?.gridSize ?: 1
    val gap = (block.data?.gap ?: 0).dp
    val direction: FlexDirection = block.data?.direction ?: FlexDirection.ROW
    val size = DpSize((block.data?.itemWidth ?: 0).dp, (block.data?.itemHeight ?: 0).dp)
    val gridHeight = (block.data?.frame?.paddingTop ?: 0) + (block.data?.frame?.paddingBottom ?: 0) + (gridSize - 1) * (block.data?.gap ?: 0) + (gridSize * (block.data?.itemHeight ?: 0))
    val gridWidth = (block.data?.frame?.paddingLeft ?: 0) + (block.data?.frame?.paddingRight ?: 0) + (gridSize - 1) * (block.data?.gap ?: 0) + (gridSize * (block.data?.itemWidth ?: 0))
    
    if (direction == FlexDirection.ROW) {
        LazyHorizontalGrid(
            contentPadding = padding,
            rows = GridCells.Fixed(gridSize),
            state = state,
            horizontalArrangement = Arrangement.spacedBy(gap),
            verticalArrangement = Arrangement.spacedBy(gap),
            modifier = modifier.height(gridHeight.dp)
        ) {
            items(children.size) {
                Box(Modifier.size(size)) {
                    Block(block = children[it])
                }
            }
        }
    } else {
        LazyVerticalGrid(
            contentPadding = padding,
            columns = GridCells.Fixed(gridSize),
            state = state,
            verticalArrangement = Arrangement.spacedBy(gap),
            horizontalArrangement = Arrangement.spacedBy(gap),
            modifier = modifier.width(gridWidth.dp)
        ) {
            items(children.size) {
                Box(Modifier.size(size)) {
                    Block(block = children[it])
                }
            }
        }
    }
}
