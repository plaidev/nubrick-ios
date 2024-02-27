package com.nativebrik.sdk.schema

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
                "children": [{
                    "__typename": "UITextBlock",
                    "id": "2",
                    "data": {
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
}
