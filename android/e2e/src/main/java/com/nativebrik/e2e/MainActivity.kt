package com.nativebrik.e2e

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.nativebrik.e2e.ui.theme.NativebrikAndroidTheme
import com.nativebrik.sdk.Config
import com.nativebrik.sdk.Nativebrik
import com.nativebrik.sdk.NativebrikClient
import com.nativebrik.sdk.NativebrikProvider
import com.nativebrik.sdk.component.EmbeddingLoadingState
import com.nativebrik.sdk.remoteconfig.RemoteConfigLoadingState

class MainActivity : ComponentActivity() {
    private lateinit var nativebrik: NativebrikClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        this.nativebrik = NativebrikClient(
            config = Config(projectId = "ckto7v223akg00ag3jsg"),
            context = this.applicationContext,
        )

        setContent {
            NativebrikAndroidTheme {
                // A surface container using the 'background' color from the theme
                NativebrikProvider(client = nativebrik) {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        Column(
                            verticalArrangement = Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            // embedding
                            Nativebrik.client.experiment.Embedding(
                                "EMBEDDING_FOR_E2E",
                                modifier = Modifier.height(240f.dp),
                                content = {
                                    when (it) {
                                        is EmbeddingLoadingState.Completed -> {
                                            it.view()
                                        }
                                        is EmbeddingLoadingState.Loading -> {
                                            CircularProgressIndicator()
                                        }
                                        else -> {
                                            Text(text = "EMBED IS FAILED")
                                        }
                                    }
                                }
                            )

                            // remote config
                            Nativebrik.client.experiment.RemoteConfig("REMOTE_CONFIG_FOR_E2E") {
                                when (it) {
                                    is RemoteConfigLoadingState.Completed -> {
                                        Text(text = it.variant.getAsString("message") ?: "")
                                    }
                                    is RemoteConfigLoadingState.Loading -> {
                                        CircularProgressIndicator()
                                    }
                                    else -> {
                                        Text(text = "CONFIG IS FAILED")
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }
}
