package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import com.nativebrik.sdk.component.provider.data.DataContext
import com.nativebrik.sdk.component.provider.event.eventDispatcher
import com.nativebrik.sdk.component.provider.event.skeleton
import com.nativebrik.sdk.schema.Color
import com.nativebrik.sdk.schema.FontDesign
import com.nativebrik.sdk.schema.FontWeight
import com.nativebrik.sdk.schema.TextAlign
import com.nativebrik.sdk.schema.UITextBlock
import com.nativebrik.sdk.template.compile
import com.nativebrik.sdk.template.hasPlaceholder
import androidx.compose.ui.graphics.Color as PrimitiveColor
import androidx.compose.ui.text.font.FontFamily as PrimitiveFontFamily
import androidx.compose.ui.text.font.FontWeight as PrimitiveFontWeight
import androidx.compose.ui.text.style.TextAlign as PrimitiveTextAlign

internal fun parseFontDesign(fontDesign: FontDesign?): PrimitiveFontFamily {
    return when (fontDesign) {
        FontDesign.DEFAULT -> PrimitiveFontFamily.Default
        FontDesign.ROUNDED -> PrimitiveFontFamily.Cursive
        FontDesign.MONOSPACE -> PrimitiveFontFamily.Monospace
        FontDesign.SERIF -> PrimitiveFontFamily.Serif
        else -> PrimitiveFontFamily.Default
    }
}

internal fun parseFontWeight(fontWeight: FontWeight?): PrimitiveFontWeight {
    return when (fontWeight) {
        FontWeight.ULTRA_LIGHT -> PrimitiveFontWeight.ExtraLight
        FontWeight.THIN -> PrimitiveFontWeight.Thin
        FontWeight.LIGHT -> PrimitiveFontWeight.Light
        FontWeight.REGULAR -> PrimitiveFontWeight.Normal
        FontWeight.MEDIUM -> PrimitiveFontWeight.Medium
        FontWeight.SEMI_BOLD -> PrimitiveFontWeight.SemiBold
        FontWeight.BOLD -> PrimitiveFontWeight.Bold
        FontWeight.HEAVY -> PrimitiveFontWeight.ExtraBold
        FontWeight.BLACK -> PrimitiveFontWeight.Black
        else -> PrimitiveFontWeight.Normal
    }
}

internal fun parseFontStyle(size: Int? = null, color: Color? = null, fontWeight: FontWeight? = null, fontDesign: FontDesign? = null, alignment: TextAlign? = null, transparent: Boolean = false): TextStyle {
    val textColor = parseColorForText(color) ?: PrimitiveColor.Black // get from theme
    return TextStyle.Default.copy(
        color = if (transparent) PrimitiveColor.Transparent else textColor,
        fontSize = size?.sp ?: 16.sp,
        fontWeight = parseFontWeight(fontWeight = fontWeight),
        fontFamily = parseFontDesign(fontDesign = fontDesign),
        textAlign = parseTextAlign(alignment = alignment),
    )
}

internal fun parseTextAlign(alignment: TextAlign?): PrimitiveTextAlign {
    return when (alignment) {
        TextAlign.CENTER -> PrimitiveTextAlign.Center
        TextAlign.LEFT -> PrimitiveTextAlign.Left
        TextAlign.RIGHT -> PrimitiveTextAlign.Right
        else -> PrimitiveTextAlign.Unspecified
    }
}

@Composable
internal fun Text(block: UITextBlock, modifier: Modifier = Modifier) {
    val data = DataContext.state
    val loading = data.loading
    var value = block.data?.value ?: ""
    var skeleton = false
    if (hasPlaceholder(block.data?.value ?: "")) {
        skeleton = loading
        value = if (loading) block.data?.value ?: "" else compile(block.data?.value ?: "", data.data)
    }

    var modifier = framedModifier(modifier, block.data?.frame)
    modifier = modifier.skeleton(skeleton).eventDispatcher(block.data?.onClick)
    val fontStyle = parseFontStyle(
        size = block.data?.size,
        color = block.data?.color,
        fontWeight = block.data?.weight,
        fontDesign = block.data?.design,
        alignment = null,
        transparent = skeleton,
    )

    BasicText(
        text = value,
        modifier = modifier,
        style = fontStyle,
    )
}