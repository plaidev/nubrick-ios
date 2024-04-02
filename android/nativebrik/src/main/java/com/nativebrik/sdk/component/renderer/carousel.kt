package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.nativebrik.sdk.component.provider.data.DataContext
import com.nativebrik.sdk.component.provider.data.NestedDataProvider
import com.nativebrik.sdk.schema.FlexDirection
import com.nativebrik.sdk.schema.UICollectionBlock
import com.nativebrik.sdk.template.variableByPath
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonArray

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun Carousel(block: UICollectionBlock, modifier: Modifier = Modifier) {
    val dataState = DataContext.state
    val reference = block.data?.reference
    var children = block.data?.children ?: emptyList()
    var arrayData: JsonArray? = null
    if (reference != null) {
        val data = variableByPath(reference, dataState.data)
        if (data is JsonArray && children.isNotEmpty()) {
            arrayData = data.jsonArray
            children = arrayData.map { children[0] }
        }
    }

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
            modifier = modifier.fillMaxWidth()
        ) {
            Box(Modifier.size(size)) {
                NestedDataProvider(data = if (arrayData != null) arrayData[it] else dataState.data) {
                    Block(block = children[it])
                }
            }
        }
    } else {
        VerticalPager(
            contentPadding = padding,
            pageSpacing = gap,
            state = state,
            pageSize = PageSize.Fixed(size.height),
            modifier = modifier.fillMaxHeight()
        ) {
            Box(Modifier.size(size)) {
                NestedDataProvider(data = if (arrayData != null) arrayData[it] else dataState.data) {
                    Block(block = children[it])
                }
            }
        }
    }
}
