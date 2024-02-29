package com.nativebrik.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
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
            config = Config(projectId = "ckto7v223akg00ag3jsg"),
            context = this.applicationContext,
        )
        setContent {
            NativebrikAndroidTheme {
                NativebrikProvider(client = nativebrik) {
                    // A surface container using the 'background' color from the theme
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        Column {
                            Greeting("Android")
                            Nativebrik.client.experiment.Embedding(
                                "SCROLLABLE_CONTENT",
                                modifier = Modifier.height(400f.dp)
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
