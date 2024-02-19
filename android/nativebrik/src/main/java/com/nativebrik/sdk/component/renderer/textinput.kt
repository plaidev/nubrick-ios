package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.UITextInputBlock

@Composable
internal fun TextInput(block: UITextInputBlock, modifier: Modifier = Modifier) {
    var value by remember { mutableStateOf(block.data?.value ?: "") }
    val placeholder = block.data?.placeholder ?: ""
    val fontStyle = parseFontStyle(
        size = block.data?.size,
        color = block.data?.color,
        fontWeight = block.data?.weight,
        fontDesign = block.data?.design,
        alignment = block.data?.textAlign,
    )
    val modifier = framedModifier(modifier, block.data?.frame).fillMaxWidth()

    BasicTextField(
        value = value,
        onValueChange = {
            value = it
        },
        modifier = modifier,
        singleLine = true,
        maxLines = 1,
        textStyle = fontStyle,
        decorationBox = {
            if (value.isEmpty()) {
                it()
                BasicText(
                    placeholder,
                    style = fontStyle,
                )
            } else {
                it()
            }
        }
    )
}
