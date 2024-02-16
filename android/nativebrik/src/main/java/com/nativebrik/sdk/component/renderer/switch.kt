package com.nativebrik.sdk.component.renderer

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.nativebrik.sdk.schema.UISwitchInputBlock
import androidx.compose.material3.Switch as MaterialSwitch

@Composable
internal fun Switch(block: UISwitchInputBlock, modifier: Modifier = Modifier) {
    var checked by remember { mutableStateOf(true) }

    MaterialSwitch(
        modifier = modifier,
        checked = checked,
        onCheckedChange = {
            checked = it
        }
    )
}
