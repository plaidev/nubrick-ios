package com.nativebrik.sdk.component

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.lifecycle.ViewModel
import com.nativebrik.sdk.NativebrikEvent
import com.nativebrik.sdk.data.Container
import com.nativebrik.sdk.schema.TriggerEventNameDefs
import com.nativebrik.sdk.schema.UIBlock
import com.nativebrik.sdk.schema.UIRootBlock
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

internal class TriggerViewModel(internal val container: Container) : ViewModel() {
    internal val modalStacks = mutableStateListOf<UIRootBlock>()

    @OptIn(DelicateCoroutinesApi::class)
    fun dispatch(event: NativebrikEvent) {
        val self = this
        GlobalScope.launch(Dispatchers.IO) {
            self.container.fetchInAppMessage(event.name).onSuccess {
                GlobalScope.launch(Dispatchers.Main) {
                    if (it is UIBlock.UnionUIRootBlock) {
                        self.modalStacks.add(it.data)
                    }
                }
            }
        }
    }

    fun handleDismiss(root: UIRootBlock) {
        modalStacks.removeIf {
            it.id == root.id
        }
    }

}

@Composable
internal fun Trigger(trigger: TriggerViewModel) {
    LaunchedEffect("") {
        trigger.dispatch(NativebrikEvent(TriggerEventNameDefs.USER_BOOT_APP.name))
    }

    if (trigger.modalStacks.isNotEmpty()) {
        for (stack in trigger.modalStacks) {
            Root(
                container = trigger.container,
                root = stack,
                embeddingVisibility = false,
                onDismiss = {
                    trigger.handleDismiss(it)
                }
            )
        }
    }
}
