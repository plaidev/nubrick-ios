package com.nativebrik.sdk.component.renderer

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.component.provider.container.ContainerContext
import com.nativebrik.sdk.data.FormValue
import com.nativebrik.sdk.schema.UISwitchInputBlock
import androidx.compose.material3.Switch as MaterialSwitch

@Composable
internal fun Switch(block: UISwitchInputBlock, modifier: Modifier = Modifier) {
    val container = ContainerContext.value
    var checked by remember {
        var value = block.data?.value ?: false
        val key = block?.data?.key
        if (key != null) {
            when (val v = container.getFormValue(key)) {
                is FormValue.Bool -> {
                    value = v.bool
                }
                else -> {
                    container.setFormValue(key, FormValue.Bool(value))
                }
            }
        }
        mutableStateOf(value)
    }

    MaterialSwitch(
        modifier = modifier,
        checked = checked,
        onCheckedChange = {
            checked = it

            val key = block?.data?.key
            if (key != null) {
                container.setFormValue(key, FormValue.Bool(it))
            }
        }
    )
}
