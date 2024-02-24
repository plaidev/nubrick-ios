package com.nativebrik.sdk.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive

internal sealed class FormValue {
    class Bool(val bool: Boolean): FormValue()
    class StrList(val list: List<String>): FormValue()
    class Str(val str: String): FormValue()

    fun toJsonElement(): JsonElement {
        return when (this) {
            is Bool -> JsonPrimitive(this.bool)
            is Str -> JsonPrimitive(this.str)
            is StrList -> JsonArray(this.list.map { JsonPrimitive(it) })
            else -> JsonNull
        }
    }
}

internal interface FormRepository {
    fun setValue(key: String, value: FormValue)
    fun getValue(key: String): FormValue?
}

internal class FormRepositoryImpl: FormRepository {
    private val map: MutableMap<String, FormValue> = mutableMapOf()

    override fun getValue(key: String): FormValue? {
        return this.map[key]
    }

    override fun setValue(key: String, value: FormValue) {
        this.map[key] = value
    }
}
