package com.nativebrik.sdk.component.renderer

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.data.FormValue
import com.nativebrik.sdk.schema.UIMultiSelectInputBlock
import com.nativebrik.sdk.schema.UISelectInputBlock
import com.nativebrik.sdk.schema.UISelectInputBlockData
import com.nativebrik.sdk.schema.UISelectInputOption

internal const val NONE_VALUE = "None"

// resolveInitialValue retrieves the value from the form context.
// If not found, it returns the default block.data.value and sets it in the form.
private fun resolveInitialValue(data: UISelectInputBlockData, container: Container): String {
    val initialValue = data.options?.find { it.value == data.value }?.value ?: NONE_VALUE
    if (data.key == null) {
        return initialValue
    }

    when (val v = container.getFormValue(data.key)) {
        is FormValue.Str -> {
            return v.str
        }

        else -> {
            container.setFormValue(data.key, FormValue.Str(initialValue))
            return initialValue
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun Select(block: UISelectInputBlock, modifier: Modifier = Modifier) {
    if (block.data == null) {
        return
    }

    val localDensity = LocalDensity.current
    val container = ContainerContext.value

    var expanded by remember { mutableStateOf(false) }
    var value by remember {
        mutableStateOf(resolveInitialValue(block.data, container))
    }
    var widthDp by remember {
        mutableStateOf(0.dp)
    }

    val options: List<UISelectInputOption> =
        block.data.options ?: listOf(UISelectInputOption(NONE_VALUE))
    val selectedOption =
        options.firstOrNull { it.value == value }

    val modifier = modifier
        .clickable {
            expanded = true
        }
        .onSizeChanged {
            widthDp = localDensity.run {
                (it.width.toFloat() / this.density).dp
            }
        }
    val selectModifier = modifier.styleByFrame(block.data.frame)
    val fontStyle = parseFontStyle(
        size = block.data.size,
        color = block.data.color,
        fontWeight = block.data.weight,
        fontDesign = block.data.design,
        alignment = block.data.textAlign,
    )

    Box(modifier) {
        Row(
            modifier = selectModifier,
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(
                text = selectedOption?.label ?: selectedOption?.value ?: block.data.placeholder
                ?: NONE_VALUE,
                style = fontStyle,
                modifier = Modifier.weight(2f)
            )
            ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(widthDp)
        ) {
            for (option in options.iterator()) {
                val handleSelect = {
                    value = option.value ?: NONE_VALUE
                    expanded = false

                    val key = block.data.key
                    if (key != null) {
                        container.setFormValue(key, FormValue.Str(value))
                    }
                }

                DropdownMenuItem(
                    leadingIcon = {
                        RadioButton(selected = option.value == value, onClick = {
                            handleSelect()
                        })
                    },
                    text = {
                        androidx.compose.material3.Text(
                            text = option.label ?: option.value ?: NONE_VALUE,
                        )
                    },
                    onClick = {
                        handleSelect()
                    }
                )
            }
        }
    }
}

internal fun selectedOptionsToText(options: List<UISelectInputOption>): String {
    return when (options.size) {
        0 -> NONE_VALUE
        1 -> {
            val first = options[0]
            first.label ?: first.value ?: NONE_VALUE
        }

        else -> "Mixed"
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MultiSelect(block: UIMultiSelectInputBlock, modifier: Modifier = Modifier) {
    val localDensity = LocalDensity.current
    val container = ContainerContext.value
    var expanded by remember { mutableStateOf(false) }
    var value by remember {
        var value = block.data?.value ?: emptyList()
        val key = block?.data?.key
        if (key != null) {
            when (val v = container.getFormValue(key)) {
                is FormValue.StrList -> {
                    value = v.list
                }

                else -> {
                    container.setFormValue(key, FormValue.StrList(value))
                }
            }
        }

        mutableStateOf(value)
    }
    var widthDp by remember {
        mutableStateOf(0.dp)
    }
    val options: List<UISelectInputOption> =
        block.data?.options ?: listOf(UISelectInputOption(NONE_VALUE))
    val selectedOptions = options.filter { option ->
        value.any {
            option.value == it
        }
    }
    val modifier = modifier
        .clickable {
            expanded = true
        }
        .onSizeChanged {
            widthDp = localDensity.run {
                (it.width.toFloat() / this.density).dp
            }
        }
    val selectModifier = Modifier
        .styleByFrame(block.data?.frame)
        .fillMaxWidth()
    val fontStyle = parseFontStyle(
        size = block.data?.size,
        color = block.data?.color,
        fontWeight = block.data?.weight,
        fontDesign = block.data?.design,
        alignment = block.data?.textAlign,
    )

    Box(modifier) {
        Row(
            modifier = selectModifier,
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(
                text = selectedOptionsToText(selectedOptions),
                style = fontStyle,
                modifier = Modifier.weight(2f)
            )
            ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(widthDp)
        ) {
            for (option in options.iterator()) {
                val handleSelect = {
                    if (option.value != null) {
                        if (value.any { option.value == it }) {
                            value = value.filter { option.value != it }
                        } else {
                            val list = mutableListOf<String>()
                            list.addAll(value)
                            list.add(option.value)
                            value = list
                        }
                    }

                    val key = block?.data?.key
                    if (key != null) {
                        container.setFormValue(key, FormValue.StrList(value))
                    }
                }
                DropdownMenuItem(
                    leadingIcon = {
                        Checkbox(checked = value.any { option.value == it }, onCheckedChange = {
                            handleSelect()
                        })
                    },
                    text = {
                        androidx.compose.material3.Text(
                            text = option.label ?: option.value ?: NONE_VALUE,
                        )
                    },
                    onClick = {
                        handleSelect()
                    } // onClick
                )
            }
        } // DropdownMenu
    }
}
