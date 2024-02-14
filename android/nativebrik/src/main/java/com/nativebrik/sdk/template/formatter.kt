package com.nativebrik.sdk.template

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive

private fun defaultFormatter(value: JsonElement?): String {
    if (value == null) {
        return ""
    }
    if (value is JsonNull) {
        return ""
    }
    if (value is JsonPrimitive) {
        return value.jsonPrimitive.content
    }
    return value.toString()
}

private fun uppercaseFormatter(value: JsonElement?): String {
    return defaultFormatter(value).uppercase()
}
private fun lowercaseFormatter(value: JsonElement?): String {
    return defaultFormatter(value).lowercase()
}

private fun jsonFormatter(value: JsonElement?): String {
    return Json.encodeToString(value)
}

internal fun formatValue(formatter: String, value: JsonElement?): String {
    return when (formatter) {
        "json" -> jsonFormatter(value)
        "upper" -> uppercaseFormatter(value)
        "lower" -> lowercaseFormatter(value)
        else -> defaultFormatter(value)
    }
}
