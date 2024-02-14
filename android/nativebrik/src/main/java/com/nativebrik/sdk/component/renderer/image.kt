package com.nativebrik.sdk.component.renderer

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import coil.compose.rememberAsyncImagePainter
import coil.request.ImageRequest
import com.nativebrik.sdk.component.provider.data.DataContext
import com.nativebrik.sdk.component.provider.event.eventDispatcher
import com.nativebrik.sdk.component.provider.event.skeleton
import com.nativebrik.sdk.schema.ImageContentMode
import com.nativebrik.sdk.schema.UIImageBlock
import com.nativebrik.sdk.template.compile
import com.nativebrik.sdk.template.hasPlaceholder
import com.nativebrik.sdk.vendor.blurhash.BlurHashDecoder

internal data class ImageFallback(
    val blurhash: String,
    val width: Int,
    val height: Int,
){}

internal fun parseImageFallbackToBlurhash(src: String): ImageFallback {
    val none = ImageFallback(blurhash = "", width = 0, height = 0)
    try {
        val uri = Uri.parse(src)
        val width = uri.getQueryParameter("w") ?: return none
        val height = uri.getQueryParameter("h") ?: return none
        val blurhash = uri.getQueryParameter("b") ?: return none
        return ImageFallback(blurhash = blurhash, width = width.toInt(), height = height.toInt())
    } catch (_: Exception) {
        return none
    }
}

internal fun parseContentModeToContentScale(contentMode: ImageContentMode?): ContentScale {
    return when (contentMode) {
        ImageContentMode.FILL -> ContentScale.Crop
        ImageContentMode.FIT -> ContentScale.Fit
        else -> ContentScale.Crop
    }
}

@Composable
internal fun Image(block: UIImageBlock, modifier: Modifier = Modifier) {
    val data = DataContext.state
    val loading = data.loading
    var src = block.data?.src ?: ""
    var skeleton = false
    if (hasPlaceholder(block.data?.src ?: "")) {
        skeleton = loading
        src = if (loading) block.data?.src ?: "" else compile(block.data?.src ?: "", data.data)
    }

    var modifier = framedModifier(modifier, block.data?.frame)
    modifier = modifier.eventDispatcher(block.data?.onClick).skeleton(skeleton)

    val fallback = parseImageFallbackToBlurhash(src)
    val decoded = BlurHashDecoder.decode(
        blurHash = fallback.blurhash,
        height = fallback.height,
        width = fallback.width
    ) ?: null
    val contentScale = parseContentModeToContentScale(block.data?.contentMode)

    AsyncImage(
        modifier = modifier,
        model = ImageRequest.Builder(LocalContext.current)
            .data(block.data?.src ?: "https://example.com/image.jpg",)
            .crossfade(true)
            .build(),
        contentDescription = null,
        placeholder = rememberAsyncImagePainter(decoded),
        contentScale = contentScale,
    )
}
