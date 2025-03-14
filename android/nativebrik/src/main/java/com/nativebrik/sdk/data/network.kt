package com.nativebrik.sdk.data

import com.nativebrik.sdk.data.user.syncDateFromHttpResponse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

internal const val CONNECT_TIMEOUT = 10 * 1000
internal const val READ_TIMEOUT = 5 * 1000

internal fun getRequestWithCache(endpoint: String, cache: CacheStore, syncDateTime: Boolean = false): Result<String> {
    val cached = cache.get(endpoint).getOrElse {
        val result = getRequest(endpoint, syncDateTime).getOrElse { error ->
            cache.invalidate(endpoint)
            return Result.failure(error)
        }
        cache.set(endpoint, result).getOrNull()
        return Result.success(result)
    }
    if (cached.isStale()) {
        CoroutineScope(Dispatchers.IO).launch {
            val result = getRequest(endpoint, syncDateTime).getOrElse {
                cache.invalidate(endpoint)
                return@launch
            }
            cache.set(endpoint, result).getOrNull()
        }
    }
    return Result.success(cached.data)
}

internal fun getRequest(endpoint: String, syncDateTime: Boolean = false): Result<String> {
    var connection: HttpURLConnection? = null
    try {
        val t0 = System.currentTimeMillis()
        val url = URL(endpoint)
        connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = CONNECT_TIMEOUT
        connection.readTimeout = READ_TIMEOUT
        connection.requestMethod = "GET"
        connection.doOutput = false
        connection.doInput = true
        connection.useCaches = true
        connection.connect()
        val responseCode = connection.responseCode

        if (syncDateTime) {
            syncDateFromHttpResponse(t0, connection)
        }

        if (responseCode == HttpURLConnection.HTTP_OK) {
            val sb = StringBuilder()
            var line: String?
            val br = BufferedReader(InputStreamReader(connection.inputStream))
            while (br.readLine().also { line = it } != null) {
                sb.append(line)
            }

            return Result.success(sb.toString())
        } else if (responseCode == HttpURLConnection.HTTP_NOT_FOUND) {
            return Result.failure(NotFoundException())
        } else {
            return Result.failure(Exception("Something happened: http status code = ${responseCode.toString()}"))
        }
    } catch (e: IOException) {
        return Result.failure(e)
    } finally {
        connection?.disconnect()
    }
}

internal fun postRequest(endpoint: String, data: String): Result<String> {
    var connection: HttpURLConnection? = null
    try {
        val url = URL(endpoint)
        connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = CONNECT_TIMEOUT
        connection.readTimeout = READ_TIMEOUT
        connection.requestMethod = "POST"
        connection.doOutput = true
        connection.doInput = true
        connection.useCaches = false
        connection.setRequestProperty("Content-Type", "application/json")

        val bodyData = data.toByteArray()
        connection.setRequestProperty("Content-Length", bodyData.size.toString())
        val outputStream = connection.outputStream
        outputStream.write(bodyData)
        outputStream.flush()
        outputStream.close()

        connection.connect()

        val responseCode = connection.responseCode
        if (responseCode == HttpURLConnection.HTTP_OK) {
            val sb = StringBuilder()
            var line: String?
            val br = BufferedReader(InputStreamReader(connection.inputStream))
            while (br.readLine().also { line = it } != null) {
                sb.append(line)
            }

            return Result.success(sb.toString())
        } else if (responseCode == HttpURLConnection.HTTP_NOT_FOUND) {
            return Result.failure(NotFoundException())
        } else {
            return Result.failure(Exception("Something happened: http status code = ${responseCode.toString()}"))
        }

    } catch (e: IOException) {
        return Result.failure(e)
    } finally {
        connection?.disconnect()
    }
}

internal fun createHttpUrlConnection(url: String): Result<HttpURLConnection> {
    try {
        val url = URL(url)
        val connection = url.openConnection() as HttpURLConnection
        return Result.success(connection)
    } catch (e: Exception) {
        return Result.failure(e)
    }
}

internal fun setBody(connection: HttpURLConnection, body: String) {
    connection.doOutput = true
    connection.useCaches = false
    connection.setRequestProperty("Content-Type", "application/json")

    val bodyData = body.toByteArray()
    connection.setRequestProperty("Content-Length", bodyData.size.toString())
    val outputStream = connection.outputStream
    outputStream.write(bodyData)
    outputStream.flush()
    outputStream.close()
}

internal fun connectAndGetResponse(connection: HttpURLConnection): Result<String> {
    try {
        connection.doInput = true
        connection.connect()
        val responseCode = connection.responseCode
        if (responseCode == HttpURLConnection.HTTP_OK) {
            val sb = StringBuilder()
            var line: String?
            val br = BufferedReader(InputStreamReader(connection.inputStream))
            while (br.readLine().also { line = it } != null) {
                sb.append(line)
            }

            return Result.success(sb.toString())
        } else if (responseCode == HttpURLConnection.HTTP_NOT_FOUND) {
            return Result.failure(NotFoundException())
        } else {
            return Result.failure(Exception("Something happened: http status code = ${responseCode.toString()}"))
        }
    } catch (e: IOException) {
        return Result.failure(e)
    } finally {
        connection?.disconnect()
    }
}

