package com.nativebrik.sdk.template

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

private data class Placeholder(val path: String, val formatter: String)

private val placeholderRegex = Regex("\\{\\{[a-zA-Z0-9_\\.-| ]{1,300}\\}\\}", option = RegexOption.DOT_MATCHES_ALL)
private fun parseToPlaceholder(value: String): Placeholder? {
    if (!hasPlaceholder(value)) {
        return null
    }
    val inside = value.replace(Regex("(\\{|\\})")) {
        ""
    }
    val identifiers = inside.split("|")
    if (identifiers.isEmpty()) {
        return null
    }
    var path = identifiers[0].trim()
    var formatter = ""
    if (identifiers.size >= 2) {
        formatter = identifiers[1].trim()
    }
    return Placeholder(
        path = path,
        formatter = formatter,
    )
}

fun hasPlaceholder(value: String): Boolean {
    return placeholderRegex.containsMatchIn(value)
}

fun variableByPath(path: String, variable: JsonElement?): JsonElement? {
    val keys = path.split(".")
    if (keys.isEmpty()) return null
    var current = variable
    keys.forEach { key ->
        if (key.isEmpty()) return@forEach
        if (key == "$") {
            current = variable
        } else {
            if (current is JsonObject) {
                current = current!!.jsonObject[key]
            } else {
                return null
            }
        }
    }
    return current
}

fun compile(template: String, variable: JsonElement?): String {
    var result = template
    return result.replace(placeholderRegex) {
        val placeholder = parseToPlaceholder(it.value) ?: return@replace ""
        val value = variableByPath(placeholder.path, variable)
        return@replace formatValue(placeholder.formatter, value)
    }
}
