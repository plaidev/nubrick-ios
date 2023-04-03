package com.nativebrik.sdk

public data class Config(
    val apiKey: String,
    val url: String = "http://localhost:8060/client",
) {
}

public class Nativebrik(config: Config) {
    final val config = config
}