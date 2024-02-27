package com.nativebrik.sdk.template

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Test

class CompilerTest {
    private val userId = "userid"
    private val teamName = "nativebrik"
    private val variable = JsonObject(mapOf(
        "user" to JsonObject(mapOf(
            "id" to JsonPrimitive(userId),
            "team" to JsonObject(mapOf(
                "name" to JsonPrimitive(teamName)
            )),
        )),
    ))

    @Test
    fun shouldCompileSimpleTemplates() {
        assertEquals(this.userId, compile("{{ user.id }}", this.variable))
        assertEquals(this.userId, compile("{{ user.id | }}", this.variable))
        assertEquals("Hello ${this.userId}", compile("Hello {{ user.id }}", this.variable))
        assertEquals("Hello ${this.userId.uppercase()}", compile("Hello {{ user.id | upper }}", this.variable))
    }

    @Test
    fun shouldCompileComplexTemplates() {
        assertEquals("Hello ${this.userId} at ${this.teamName}", compile("Hello {{user.id}} at {{user.team.name}}", this.variable))
    }

    @Test
    fun shouldHasPlaceholderWork() {
        assertEquals(true, hasPlaceholder("hello {{user.id}}"))
        assertEquals(true, hasPlaceholder("hello {{user.id}} {{ test.id|json}}"))
        assertEquals(false, hasPlaceholder("hello {user.id}"))
    }

    @Test
    fun shouldGetVariableByPath() {
        assertEquals(JsonPrimitive(this.userId), variableByPath("user.id", this.variable))
        assertEquals(null, variableByPath("user.xxx.yyy", this.variable))
        assertEquals(JsonPrimitive(this.teamName), variableByPath("$.user.team.name", this.variable))
        assertEquals(this.variable["user"]?.jsonObject, variableByPath("$.user", this.variable))
    }
}

class FormatterTest {
    @Test
    fun jsonFormatter() {
        val actual = formatValue("json", JsonObject(mapOf(
            "Hello" to JsonPrimitive("World")
        )))
        assertEquals("{\"Hello\":\"World\"}", actual)
    }

    @Test
    fun uppercaseFormatter() {
        val actual = formatValue("upper", JsonPrimitive("Hello World"))
        assertEquals("HELLO WORLD", actual)
    }

    @Test
    fun lowercaseFormatter() {
        val actual = formatValue("lower", JsonPrimitive("Hello World"))
        assertEquals("hello world", actual)
    }

    @Test
    fun defaultFormatter() {
        val actual = formatValue("XYZ", JsonPrimitive(100))
        assertEquals("100", actual)
    }
}