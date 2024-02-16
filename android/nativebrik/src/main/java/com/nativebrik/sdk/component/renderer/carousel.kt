package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.nativebrik.sdk.schema.FlexDirection
import com.nativebrik.sdk.schema.UICollectionBlock

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun Carousel(block: UICollectionBlock, modifier: Modifier = Modifier) {
    val children = block.data?.children ?: emptyList()
    val state = rememberPagerState {
        children.size
    }
    val padding = parseFramePadding(block.data?.frame)
    val gap = (block.data?.gap ?: 0).dp
    val direction: FlexDirection = block.data?.direction ?: FlexDirection.ROW
    val size = DpSize((block.data?.itemWidth ?: 0).dp, (block.data?.itemHeight ?: 0).dp)
    if (direction == FlexDirection.ROW) {
        HorizontalPager(
            contentPadding = padding,
            pageSpacing = gap,
            state = state,
            pageSize = PageSize.Fixed(size.width),
            modifier = modifier
        ) {
            Box(Modifier.size(size)) {
                Block(block = children[it])
            }
        }
    } else {
        VerticalPager(
            contentPadding = padding,
            pageSpacing = gap,
            state = state,
            pageSize = PageSize.Fixed(size.height),
            modifier = modifier
        ) {
            Box(Modifier.size(size)) {
                Block(block = children[it])
            }
        }
    }
}
