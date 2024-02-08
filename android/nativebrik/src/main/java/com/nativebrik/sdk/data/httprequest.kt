package com.nativebrik.sdk.data

import com.nativebrik.sdk.schema.ApiHttpRequest
import com.nativebrik.sdk.schema.ApiHttpRequestMethod
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
interface HttpRequestRepository {
    suspend fun request(req: ApiHttpRequest): Result<JsonElement>
}

class HttpRequestRepositoryImpl(): HttpRequestRepository {
    override suspend fun request(req: ApiHttpRequest): Result<JsonElement> {
        return withContext(Dispatchers.IO) {
            val url = req.url ?: return@withContext Result.failure(SkipHttpRequestException())
            val connection = createHttpUrlConnection(url).getOrElse {
                return@withContext Result.failure(it)
            }
            val method = req.method ?: ApiHttpRequestMethod.GET
            connection.requestMethod = method.toString()

            // can send data as body
            if (method != ApiHttpRequestMethod.GET && method != ApiHttpRequestMethod.TRACE) run {
                val body = req.body ?: ""
                setBody(connection, body)
            }

            val response: String = connectAndGetResponse(connection).getOrElse {
                return@withContext Result.failure(it)
            }
            val json = Json.decodeFromString<JsonElement>(response)
            return@withContext Result.success(json)
        }
    }
}
