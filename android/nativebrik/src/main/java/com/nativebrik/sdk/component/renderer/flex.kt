package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.unit.dp
import com.nativebrik.sdk.component.provider.event.eventDispatcher
import com.nativebrik.sdk.schema.AlignItems
import com.nativebrik.sdk.schema.FlexDirection
import com.nativebrik.sdk.schema.FrameData
import com.nativebrik.sdk.schema.JustifyContent
import com.nativebrik.sdk.schema.Overflow
import com.nativebrik.sdk.schema.UIFlexContainerBlock
import com.nativebrik.sdk.schema.Color as SchemaColor

fun framedModifier(modifier: Modifier, frame: FrameData?): Modifier {
    var mod: Modifier = modifier

    // size should be set most lastly to make padding insets.
    // width should be content fit by default
    if (frame?.width != null) {
        if  (frame.width == 0) {
            // parent fit
            mod = mod.fillMaxWidth()
        } else {
            // fixed size
            mod = mod.width(frame.width.dp)
        }
    }

    // height should be content fit by default
    if (frame?.height != null) {
        if (frame.height == 0) {
            // parent fit
            mod = mod.fillMaxHeight()
        } else {
            // fixed size
            mod = mod.height(frame.height.dp)
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

    mod = mod.padding(
        start = frame?.paddingLeft?.dp ?: 0.dp,
        top = frame?.paddingTop?.dp ?: 0.dp,
        end = frame?.paddingRight?.dp ?: 0.dp,
        bottom = frame?.paddingBottom?.dp ?: 0.dp,
    )

    return mod
}

@Composable
fun overflowModifier(modifier: Modifier, direction: FlexDirection, overflow: Overflow?): Modifier {
    val overflow = overflow ?: return modifier
    if (overflow != Overflow.SCROLL) return modifier
    if (direction == FlexDirection.ROW) {
        return modifier
            .horizontalScroll(rememberScrollState())
    } else {
        return modifier
            .verticalScroll(rememberScrollState())
    }
}

fun parseColor(color: SchemaColor?): Color {
    return Color(
        red = color?.red ?: 0f,
        green = color?.green ?: 0f,
        blue = color?.blue ?: 0f,
        alpha = color?.alpha ?: 0f,
    )
}

fun parseColorForText(color: SchemaColor?): Color? {
    if (color?.red == null) return null
    return parseColor(color)
}

fun parseHorizontalAlignItems(alignItems: AlignItems?): Alignment.Horizontal {
    return when (alignItems) {
        AlignItems.START -> Alignment.Start
        AlignItems.CENTER -> Alignment.CenterHorizontally
        AlignItems.END -> Alignment.End
        else -> Alignment.CenterHorizontally
    }
}

fun parseVerticalAlignItems(alignItems: AlignItems?): Alignment.Vertical {
    return when (alignItems) {
        AlignItems.START -> Alignment.Top
        AlignItems.CENTER -> Alignment.CenterVertically
        AlignItems.END -> Alignment.Bottom
        else -> Alignment.CenterVertically
    }
}

fun parseHorizontalJustifyContent(gap: Int?, justifyContent: JustifyContent?): Arrangement.Horizontal {
    val gap = gap?.dp ?: 0.dp
    return when (justifyContent) {
        JustifyContent.START -> Arrangement.spacedBy(gap, Alignment.Start)
        JustifyContent.CENTER -> Arrangement.spacedBy(gap, Alignment.CenterHorizontally)
        JustifyContent.END -> Arrangement.spacedBy(gap, Alignment.End)
        JustifyContent.SPACE_BETWEEN -> Arrangement.SpaceBetween
        else -> Arrangement.spacedBy(gap, Alignment.CenterHorizontally)
    }
}

fun parseVerticalJustifyContent(gap: Int?, justifyContent: JustifyContent?): Arrangement.Vertical {
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
fun Flex(
    block: UIFlexContainerBlock,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val direction: FlexDirection = block.data?.direction ?: FlexDirection.ROW
    var modifier = framedModifier(modifier, block.data?.frame)
    modifier = overflowModifier(modifier, direction, block.data?.overflow)
    modifier = modifier.eventDispatcher(block.data?.onClick)
    val gap = block.data?.gap
    val justifyContent = block.data?.justifyContent
    val alignItems = block.data?.alignItems

    if (direction == FlexDirection.ROW) {
        Row(
            modifier = modifier,
            horizontalArrangement = parseHorizontalJustifyContent(gap, justifyContent),
            verticalAlignment = parseVerticalAlignItems(alignItems),
        ) {
            content()
        }
    } else {
        Column(
            modifier = modifier,
            horizontalAlignment = parseHorizontalAlignItems(alignItems),
            verticalArrangement = parseVerticalJustifyContent(gap, justifyContent)
        ) {
            content()
        }
    }
}
