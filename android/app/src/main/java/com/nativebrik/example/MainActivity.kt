package com.nativebrik.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nativebrik.example.ui.theme.NativebrikAndroidTheme
import com.nativebrik.sdk.Config
import com.nativebrik.sdk.Nativebrik
import com.nativebrik.sdk.NativebrikClient
import com.nativebrik.sdk.NativebrikProvider

class MainActivity : ComponentActivity() {
    private lateinit var nativebrik: NativebrikClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        this.nativebrik = NativebrikClient(
            config = Config(projectId = "cgv3p3223akg00fod19g"),
            context = this.applicationContext,
        )

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            this.nativebrik.experiment.record(throwable)
        }

        setContent {
            NativebrikAndroidTheme {
                NativebrikProvider(client = nativebrik) {
                    // A surface container using the 'background' color from the theme
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        Column(
                            modifier = Modifier.verticalScroll(rememberScrollState())
                        ) {
                            Nativebrik.client.experiment.Embedding(
                                "HEADER_INFORMATION",
                                arguments = emptyMap<String, String>(),
                                modifier = Modifier.height(100f.dp),
                            )
                            Nativebrik.client.experiment.Embedding(
                                "TOP_COMPONENT",
                                arguments = emptyMap<String, String>(),
                                modifier = Modifier.height(270f.dp),
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        this.nativebrik.close()
        super.onDestroy()
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    NativebrikAndroidTheme {
        Greeting("Android")
    }
}
