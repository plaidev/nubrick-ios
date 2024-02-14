package com.nativebrik.sdk.data

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

const val CONNECT_TIMEOUT = 10 * 1000
const val READ_TIMEOUT = 5 * 1000

fun getRequest(endpoint: String): Result<String> {
    var connection: HttpURLConnection? = null
    try {
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

fun postRequest(endpoint: String, data: String): Result<String> {
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

fun createHttpUrlConnection(url: String): Result<HttpURLConnection> {
    try {
        val url = URL(url)
        val connection = url.openConnection() as HttpURLConnection
        return Result.success(connection)
    } catch (e: Exception) {
        return Result.failure(e)
    }
}

fun setBody(connection: HttpURLConnection, body: String) {
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

fun connectAndGetResponse(connection: HttpURLConnection): Result<String> {
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

