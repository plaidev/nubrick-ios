package com.nativebrik.sdk.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive

internal sealed class FormValue {
    class Bool(val bool: Boolean) : FormValue()
    class StrList(val list: List<String>) : FormValue()
    class Str(val str: String) : FormValue()

    fun toJsonElement(): JsonElement {
        return when (this) {
            is Bool -> JsonPrimitive(this.bool)
            is Str -> JsonPrimitive(this.str)
            is StrList -> JsonArray(this.list.map { JsonPrimitive(it) })
        }
    }
}

typealias FormValueListener = (values: Map<String, JsonElement>) -> Unit


internal interface FormRepository {
    fun getFormData(): Map<String, JsonElement>
    fun setValue(key: String, value: FormValue)
    fun getValue(key: String): FormValue?
    fun addListener(listener: FormValueListener)
    fun removeListener(listener: FormValueListener)
}

internal class FormRepositoryImpl : FormRepository {
    private val map: MutableMap<String, FormValue> = mutableMapOf()
    private val listeners: MutableSet<FormValueListener> = mutableSetOf()

    override fun getFormData(): Map<String, JsonElement> {
        return this.map.entries.associate { it.key to it.value.toJsonElement() }
    }

    override fun getValue(key: String): FormValue? {
        return this.map[key]
    }

    override fun setValue(key: String, value: FormValue) {
        this.map[key] = value
        val values = this.getFormData()
        listeners.forEach { listener ->
            listener(values)
        }
    }

    override fun addListener(listener: FormValueListener) {
        this.listeners.add(listener)
    }

    override fun removeListener(listener: FormValueListener) {
        this.listeners.remove(listener)
    }
}
