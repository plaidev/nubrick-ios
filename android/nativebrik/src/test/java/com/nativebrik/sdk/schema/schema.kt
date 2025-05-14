package com.nativebrik.sdk.schema

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import org.junit.Assert.assertEquals
import org.junit.Test

class SchemaUnitTest {
    private val json = """
        {
            "__typename": "UIFlexContainerBlock",
            "id": "1",
            "data": {
                "__typename": "UIFlexContainerBlockData",
                "children": [{
                    "__typename": "UITextBlock",
                    "id": "2",
                    "data": {
                        "__typename": "UITextBlockData",
                        "value": "Hello World"
                    }
                }],
                "gap": 16
            }
        }
    """.trimIndent()

    @Test
    fun shouldDecode() {
        val jsonElement = Json.decodeFromString<JsonElement>(this.json)
        val block = UIBlock.decode(jsonElement)
        if (block is UIBlock.UnionUIFlexContainerBlock) {
            assertEquals("1", block.data.id)
            assertEquals(16, block.data.data?.gap)
            assertEquals(1, block.data.data?.children?.size)
            val child = block.data.data?.children?.get(0) as? UIBlock.UnionUITextBlock
            assertEquals("Hello World", child?.data?.data?.value)
        } else {
            assert(false)
        }
    }

    @Test
    fun shouldEncode() {
        val data = UIFlexContainerBlock(
            id = "1",
            data = UIFlexContainerBlockData(
                children = listOf(UIBlock.UnionUITextBlock(
                    UITextBlock(
                        id = "2",
                        data = UITextBlockData(
                            value = "Hello World"
                        )
                    )
                )),
                gap = 16
            )
        )
        val jsonElement = UIFlexContainerBlock.encode(data)
        val actual = Json.encodeToString(jsonElement)
        val expected = Json.encodeToString(Json.decodeFromString<JsonElement>(this.json))
        assertEquals(expected, actual)
    }

    @Test
    fun shouldEncodeEnum() {
        val data = AlignItems.START
        val actual = Json.encodeToString(AlignItems.encode(data))
        val expected = "\"START\""
        assertEquals(expected, actual)
    }
}
