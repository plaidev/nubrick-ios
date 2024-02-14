package com.nativebrik.sdk.data

import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.schema.Property
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject

internal fun createVariableForTemplate(
    user: NativebrikUser? = null,
    data: JsonElement? = null,
    properties: List<Property>? = null,
    form: Map<String, Any>? = null,
): JsonElement {
    val userJsonObject = JsonObject(mapOf(
        "id" to JsonPrimitive(user?.id ?: "")
    ))
    val propertiesJsonObject = JsonObject(properties?.associate { (it.name ?: "") to JsonPrimitive(it.value) } ?: emptyMap())
    return JsonObject(mapOf(
        "user" to userJsonObject,
        "props" to propertiesJsonObject,
        "form" to JsonPrimitive(null),
        "data" to (data ?: JsonPrimitive(null)),
    ))
}

@OptIn(ExperimentalSerializationApi::class)
internal fun mergeVariableForTemplate(
    a: JsonElement,
    b: JsonElement
): JsonElement {
    if (a !is JsonObject && b !is JsonObject) {
        return JsonObject(emptyMap())
    }
    if (a !is JsonObject) {
        return b
    }
    if (b !is JsonObject) {
        return a
    }
    return JsonObject(mapOf(
        "user" to (b.jsonObject["user"] ?: a.jsonObject["user"] ?: JsonPrimitive(null)),
        "props" to (b.jsonObject["props"] ?: a.jsonObject["props"] ?: JsonPrimitive(null)),
        "forms" to (b.jsonObject["forms"] ?: a.jsonObject["forms"] ?: JsonPrimitive(null)),
        "data" to (b.jsonObject["data"] ?: a.jsonObject["data"] ?: JsonPrimitive(null)),
    ))
}
