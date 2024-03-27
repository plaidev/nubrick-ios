package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.nativebrik.sdk.component.provider.event.eventDispatcher
import com.nativebrik.sdk.schema.AlignItems
import com.nativebrik.sdk.schema.FlexDirection
import com.nativebrik.sdk.schema.FrameData
import com.nativebrik.sdk.schema.JustifyContent
import com.nativebrik.sdk.schema.Overflow
import com.nativebrik.sdk.schema.UIBlock
import com.nativebrik.sdk.schema.UIFlexContainerBlock
import com.nativebrik.sdk.schema.Color as SchemaColor

private fun calcWeight(frameData: FrameData?, flexDirection: FlexDirection): Float? {
    if (flexDirection == FlexDirection.ROW) {
        if (frameData?.width != null && frameData.width == 0) {
            return 1f
        }
    } else {
        if (frameData?.height != null && frameData.height == 0) {
            return 1f
        }
    }
    return null
}

private fun childFrameWeight(block: UIBlock, direction: FlexDirection): Float? {
    return when (block) {
        is UIBlock.UnionUITextBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUIImageBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUIFlexContainerBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUICollectionBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUIMultiSelectInputBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUISelectInputBlock -> calcWeight(block.data.data?.frame, direction)
        is UIBlock.UnionUITextInputBlock -> calcWeight(block.data.data?.frame, direction)
        else -> null
    }
}

@Composable
internal fun Modifier.styleByFrame(frame: FrameData?): Modifier {
    return this
        .frameSize(frame)
        .framePadding(frame)
}


@Composable
internal fun Modifier.frameSize(frame: FrameData?): Modifier {
    var mod = this
    // size should be set most lastly to make padding insets.
    // width should be content fit by default
    if (frame?.width != null) {
        mod = if (frame.width == 0) {
            // parent fit
            mod.fillMaxWidth()
        } else {
            // fixed size
            mod.width(frame.width.dp)
        }
    }

    // height should be content fit by default
    if (frame?.height != null) {
        mod = if (frame.height == 0) {
            // parent fit
            mod.fillMaxHeight()
        } else {
            // fixed size
            mod.height(frame.height.dp)
        }
    }

    val roundedShape = RoundedCornerShape(frame?.borderRadius?.dp ?: 0.dp)
    mod = mod.clip(roundedShape)
    if (frame?.background != null) {
        mod = mod.background(parseColor(frame.background))
    }
    mod = mod.border(
        width = frame?.borderWidth?.dp ?: 1.dp,
        color = parseColor(frame?.borderColor),
        shape = roundedShape,
    )

    return mod
}

@Composable
internal fun Modifier.framePadding(frame: FrameData?): Modifier {
    return this.padding(
        start = frame?.paddingLeft?.dp ?: 0.dp,
        top = frame?.paddingTop?.dp ?: 0.dp,
        end = frame?.paddingRight?.dp ?: 0.dp,
        bottom = frame?.paddingBottom?.dp ?: 0.dp,
    )
}


internal fun parseFramePadding(frame: FrameData?): PaddingValues {
    return PaddingValues(
        start = frame?.paddingLeft?.dp ?: 0.dp,
        top = frame?.paddingTop?.dp ?: 0.dp,
        end = frame?.paddingRight?.dp ?: 0.dp,
        bottom = frame?.paddingBottom?.dp ?: 0.dp,
    )
}
@Composable
internal fun Modifier.flexOverflow(direction: FlexDirection, overflow: Overflow?): Modifier {
    val overflow = overflow ?: return this
    if (overflow != Overflow.SCROLL) return this
    return if (direction == FlexDirection.ROW) {
        this
            .horizontalScroll(rememberScrollState())
    } else {
        this
            .verticalScroll(rememberScrollState())
    }
}

internal fun parseColor(color: SchemaColor?): Color {
    return Color(
        red = color?.red ?: 0f,
        green = color?.green ?: 0f,
        blue = color?.blue ?: 0f,
        alpha = color?.alpha ?: 0f,
    )
}

internal fun parseColorForText(color: SchemaColor?): Color? {
    if (color?.red == null) return null
    return parseColor(color)
}

internal fun parseHorizontalAlignItems(alignItems: AlignItems?): Alignment.Horizontal {
    return when (alignItems) {
        AlignItems.START -> Alignment.Start
        AlignItems.CENTER -> Alignment.CenterHorizontally
        AlignItems.END -> Alignment.End
        else -> Alignment.CenterHorizontally
    }
}

internal fun parseVerticalAlignItems(alignItems: AlignItems?): Alignment.Vertical {
    return when (alignItems) {
        AlignItems.START -> Alignment.Top
        AlignItems.CENTER -> Alignment.CenterVertically
        AlignItems.END -> Alignment.Bottom
        else -> Alignment.CenterVertically
    }
}

internal fun parseHorizontalJustifyContent(gap: Int?, justifyContent: JustifyContent?): Arrangement.Horizontal {
    val gap = gap?.dp ?: 0.dp
    return when (justifyContent) {
        JustifyContent.START -> Arrangement.spacedBy(gap, Alignment.Start)
        JustifyContent.CENTER -> Arrangement.spacedBy(gap, Alignment.CenterHorizontally)
        JustifyContent.END -> Arrangement.spacedBy(gap, Alignment.End)
        JustifyContent.SPACE_BETWEEN -> Arrangement.SpaceBetween
        else -> Arrangement.spacedBy(gap, Alignment.CenterHorizontally)
    }
}

internal fun parseVerticalJustifyContent(gap: Int?, justifyContent: JustifyContent?): Arrangement.Vertical {
    val gap = gap?.dp ?: 0.dp
    return when (justifyContent) {
        JustifyContent.START -> Arrangement.spacedBy(gap, Alignment.Top)
        JustifyContent.CENTER -> Arrangement.spacedBy(gap, Alignment.CenterVertically)
        JustifyContent.END -> Arrangement.spacedBy(gap, Alignment.Bottom)
        JustifyContent.SPACE_BETWEEN -> Arrangement.SpaceBetween
        else -> Arrangement.spacedBy(gap, Alignment.CenterVertically)
    }
}

@Composable
internal fun Flex(
    block: UIFlexContainerBlock,
    modifier: Modifier = Modifier,
) {
    val direction: FlexDirection = block.data?.direction ?: FlexDirection.ROW
    val modifier = modifier.frameSize(block.data?.frame)
    val flexModifier = modifier
        .framePadding(block.data?.frame)
        .flexOverflow(direction, block.data?.overflow)
        .eventDispatcher(block.data?.onClick)

    val gap = block.data?.gap
    val justifyContent = block.data?.justifyContent
    val alignItems = block.data?.alignItems

    Box(modifier = modifier) {
        if (block.data?.frame?.backgroundSrc != null) {
            AsyncImage(
                modifier = Modifier
                    .zIndex(0f)
                    .matchParentSize(),
                model = ImageRequest.Builder(LocalContext.current)
                    .data(block.data.frame.backgroundSrc)
                    .crossfade(true)
                    .build(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
            )
        }
        if (direction == FlexDirection.ROW) {
            Row(
                modifier = flexModifier.zIndex(1f),
                horizontalArrangement = parseHorizontalJustifyContent(gap, justifyContent),
                verticalAlignment = parseVerticalAlignItems(alignItems),
            ) {
                block.data?.children?.map {
                    val weight = childFrameWeight(it, direction)
                    Block(block = it, if (weight != null) Modifier.weight(weight) else Modifier)
                }
            }
        } else {
            Column(
                modifier = flexModifier.zIndex(1f),
                horizontalAlignment = parseHorizontalAlignItems(alignItems),
                verticalArrangement = parseVerticalJustifyContent(gap, justifyContent)
            ) {
                block.data?.children?.map {
                    val weight = childFrameWeight(it, direction)
                    Block(block = it, if (weight != null) Modifier.weight(weight) else Modifier)
                }
            }
        }
    }


}
