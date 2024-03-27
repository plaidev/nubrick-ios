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
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.data.FormValue
import com.nativebrik.sdk.schema.UITextInputBlock

@Composable
internal fun TextInput(block: UITextInputBlock, modifier: Modifier = Modifier) {
    val container = ContainerContext.value
    var value by remember {
        var value = block.data?.value ?: ""
        val key = block?.data?.key
        if (key != null) {
            when (val v = container.getFormValue(key)) {
                is FormValue.Str -> {
                    value = v.str
                }
                else -> {}
            }
        }

        mutableStateOf(value)
    }
    val placeholder = block.data?.placeholder ?: ""
    val fontStyle = parseFontStyle(
        size = block.data?.size,
        color = block.data?.color,
        fontWeight = block.data?.weight,
        fontDesign = block.data?.design,
        alignment = block.data?.textAlign,
    )
    val modifier = modifier.styleByFrame(block.data?.frame).fillMaxWidth()

    BasicTextField(
        value = value,
        onValueChange = {
            value = it

            val key = block?.data?.key
            if (key != null) {
                container.setFormValue(key, FormValue.Str(it))
            }
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
