package com.nativebrik.sdk.data

import com.nativebrik.sdk.Config
import com.nativebrik.sdk.schema.ExperimentConfigs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

internal interface ExperimentRepository {
    suspend fun fetchExperimentConfigs(id: String): Result<ExperimentConfigs>
    suspend fun fetchTriggerExperimentConfigs(name: String): Result<ExperimentConfigs>
}

internal class ExperimentRepositoryImpl(private val config: Config): ExperimentRepository {
    override suspend fun fetchExperimentConfigs(
        id: String
    ): Result<ExperimentConfigs> {
        return withContext(Dispatchers.IO) {
            val url = config.endpoint.cdn + "/projects/" + config.projectId + "/experiments/id/" + id
            val response: String = getRequest(url).getOrElse {
                return@withContext Result.failure(it)
            }
            val json = Json.decodeFromString<JsonElement>(response)
            val configs = ExperimentConfigs.decode(json) ?: return@withContext Result.failure(FailedToDecodeException())
            return@withContext Result.success(configs)
        }
    }

    override suspend fun fetchTriggerExperimentConfigs(name: String): Result<ExperimentConfigs> {
        return withContext(Dispatchers.IO) {
            val url = config.endpoint.cdn + "/projects/" + config.projectId + "/experiments/trigger/" + name
            val response: String = getRequest(url).getOrElse {
                return@withContext Result.failure(it)
            }
            val json = Json.decodeFromString<JsonElement>(response)
            val configs = ExperimentConfigs.decode(json) ?: return@withContext Result.failure(FailedToDecodeException())
            return@withContext Result.success(configs)
        }
    }
}
