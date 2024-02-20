package com.nativebrik.sdk.component.renderer

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewPage(url: String, modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                this.webViewClient = WebViewClient()
                this.settings.javaScriptEnabled = true
                this.settings.useWideViewPort = true
                this.settings.setSupportZoom(true)
                this.isVerticalScrollBarEnabled = true
            }
        },
        update = { webView ->
            webView.loadUrl(url)
        }
    )
}
