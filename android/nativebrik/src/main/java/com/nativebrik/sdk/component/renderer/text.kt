package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import com.nativebrik.sdk.schema.Color
import com.nativebrik.sdk.schema.FontDesign
import com.nativebrik.sdk.schema.FontWeight
import com.nativebrik.sdk.schema.UITextBlock
import androidx.compose.ui.graphics.Color as PrimitiveColor
import androidx.compose.ui.text.font.FontFamily as PrimitiveFontFamily
import androidx.compose.ui.text.font.FontWeight as PrimitiveFontWeight

fun parseFontDesign(fontDesign: FontDesign?): PrimitiveFontFamily {
    return when (fontDesign) {
        FontDesign.DEFAULT -> PrimitiveFontFamily.Default
        FontDesign.ROUNDED -> PrimitiveFontFamily.Cursive
        FontDesign.MONOSPACE -> PrimitiveFontFamily.Monospace
        FontDesign.SERIF -> PrimitiveFontFamily.Serif
        else -> PrimitiveFontFamily.Default
    }
}


fun parseFontWeight(fontWeight: FontWeight?): PrimitiveFontWeight {
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

fun parseFontStyle(size: Int?, color: Color?, fontWeight: FontWeight?, fontDesign: FontDesign?): TextStyle {
    val textColor = parseColorForText(color) ?: PrimitiveColor.Black // get from theme
    return TextStyle.Default.copy(
        color = textColor,
        fontSize = size?.sp ?: 16.sp,
        fontWeight = parseFontWeight(fontWeight = fontWeight),
        fontFamily = parseFontDesign(fontDesign = fontDesign),
    )
}



@Composable
fun Text(block: UITextBlock, modifier: Modifier = Modifier) {
    val value = block.data?.value ?: ""
    val modifier = framedModifier(modifier, block.data?.frame)
    val fontStyle = parseFontStyle(
        size = block.data?.size,
        color = block.data?.color,
        fontWeight = block.data?.weight,
        fontDesign = block.data?.design,
    )
    BasicText(
        text = value,
        modifier = modifier,
        style = fontStyle,
    )
}