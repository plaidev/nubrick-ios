package com.nativebrik.sdk.component.provider.pageblock

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import com.nativebrik.sdk.schema.Property
import com.nativebrik.sdk.schema.UIPageBlock

internal data class PageBlockData(val block: UIPageBlock, val properties: List<Property>? = null) {
    fun toProperties(): List<Property>? {
        return this.block.data?.props?.map {
            val found = properties?.firstOrNull {prop ->
                prop.name == it.name
            }
            Property(it.name, found?.value ?: it.value)
        }
    }
}

internal var LocalPageBlock = compositionLocalOf<PageBlockData> {
    error("LocalPageBlock is not found")
}

internal object PageBlockContext {
    /**
     * Retrieves the current [LocalPageBlock] at the call site's position in the hierarchy.
     */
    val value: PageBlockData
        @Composable
        @ReadOnlyComposable
        get() = LocalPageBlock.current
}

@Composable
internal fun PageBlockProvider(
    pageBlock: PageBlockData,
    content: @Composable() () -> Unit,
) {
    CompositionLocalProvider(
        LocalPageBlock provides pageBlock
    ) {
        content()
    }
}
