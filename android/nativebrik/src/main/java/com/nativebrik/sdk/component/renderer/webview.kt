package com.nativebrik.sdk.component.renderer

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewPage(url: String, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val webViewState = remember { mutableStateOf<WebView?>(null) }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                this.webViewClient = WebViewClient()
                this.settings.javaScriptEnabled = true
                this.settings.useWideViewPort = true
                this.settings.setSupportZoom(true)
                this.isVerticalScrollBarEnabled = true
                loadUrl(url)
                webViewState.value = this
            }
        },
        update = { webView ->
            webView.loadUrl(url)
        }
    )

    BackHandler(enabled = true) {
        val webView = webViewState.value
        if (webView != null && webView.canGoBack()) {
            // history back
            webView.goBack()
        } else {
            // close dialog
            onDismiss()
        }
    }
}
