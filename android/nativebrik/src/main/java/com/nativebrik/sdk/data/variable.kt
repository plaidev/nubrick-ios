package com.nativebrik.sdk.data

import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.schema.BuiltinUserProperty
import com.nativebrik.sdk.schema.Property
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

internal fun createVariableForTemplate(
    user: NativebrikUser? = null,
    data: JsonElement? = null,
    properties: List<Property>? = null,
    form: Map<String, JsonElement>? = null,
    arguments: Any? = null,
    projectId: String? = null,
): JsonElement {
    val userData = mutableMapOf("id" to JsonPrimitive(user?.id ?: ""))
    user?.getProperties()?.forEach { (key, value) ->
        if (key == BuiltinUserProperty.userId.toString()) return@forEach
        userData[key] = JsonPrimitive(value)
    }
    val userJsonObject = JsonObject(userData.toMap())

    val propertiesJsonObject = JsonObject(properties?.associate { (it.name ?: "") to JsonPrimitive(it.value) } ?: emptyMap())
    val formJsonObject = JsonObject(form?.entries?.associate {
        it.key to it.value
    } ?: emptyMap())
    return JsonObject(mapOf(
        "user" to userJsonObject,
        "props" to propertiesJsonObject,
        "form" to formJsonObject,
        "args" to buildJsonElement(arguments),
        "data" to (data ?: JsonNull),
        "project" to JsonObject(mapOf(
            "id" to JsonPrimitive(projectId),
        ))
    ))
}

internal fun buildJsonElement(value: Any?): JsonElement {
    if (value == null) return JsonNull
    when (value) {
        is Map<*, *> -> {
            return JsonObject(value.map {
                it.key.toString() to buildJsonElement(it.value)
            }.toMap())
        }
        is List<*> -> {
            return JsonArray(value.map { buildJsonElement(it) })
        }
        is Array<*> -> {
            return JsonArray(value.map { buildJsonElement(it) })
        }
        is Int -> {
            return JsonPrimitive(value)
        }
        is Float -> {
            return JsonPrimitive(value)
        }
        is Double -> {
            return JsonPrimitive(value)
        }
        is String -> {
            return JsonPrimitive(value)
        }
        else -> {
            return JsonPrimitive(value.toString())
        }
    }
}