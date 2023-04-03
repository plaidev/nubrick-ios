package com.nativebrik.example

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import com.nativebrik.sdk.Config
import com.nativebrik.sdk.Nativebrik

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Nativebrik(config = Config(
            apiKey = "hello"
        ))
    }
}