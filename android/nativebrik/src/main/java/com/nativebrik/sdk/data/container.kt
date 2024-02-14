package com.nativebrik.sdk.data

import android.content.Context
import com.nativebrik.sdk.Config
import com.nativebrik.sdk.data.extraction.extractComponentId
import com.nativebrik.sdk.data.extraction.extractExperimentConfig
import com.nativebrik.sdk.data.extraction.extractExperimentVariant
import com.nativebrik.sdk.data.user.NativebrikUser
import com.nativebrik.sdk.schema.ApiHttpHeader
import com.nativebrik.sdk.schema.ApiHttpRequest
import com.nativebrik.sdk.schema.ExperimentConfigs
import com.nativebrik.sdk.schema.ExperimentKind
import com.nativebrik.sdk.schema.ExperimentVariant
import com.nativebrik.sdk.schema.Property
import com.nativebrik.sdk.schema.UIBlock
import com.nativebrik.sdk.template.compile
import kotlinx.serialization.json.JsonElement

class NotFoundException: Exception("Not found")
class FailedToDecodeException: Exception("Failed to decode")
class SkipHttpRequestException: Exception("Skip http request")

interface Container {
    fun createVariableForTemplate(data: JsonElement? = null, properties: List<Property>? = null): JsonElement

    suspend fun sendHttpRequest(req: ApiHttpRequest, data: JsonElement? = null): Result<JsonElement>
    suspend fun fetchEmbedding(experimentId: String): Result<UIBlock>
    suspend fun fetchInAppMessage(trigger: String): Result<UIBlock>
    suspend fun fetchRemoteConfig(experimentId: String): Result<String>
}

class ContainerImpl(
    private val config: Config,
    private val user: NativebrikUser,
    private val context: Context,
): Container {
    private val componentRepository: ComponentRepository by lazy {
        ComponentRepositoryImpl(config)
    }
    private val experimentRepository: ExperimentRepository by lazy {
        ExperimentRepositoryImpl(config)
    }
    private val trackRepository: TrackRepository by lazy {
        TrackRepositoryImpl(config)
    }
    private val httpRequestRepository: HttpRequestRepository by lazy {
        HttpRequestRepositoryImpl()
    }

    override fun createVariableForTemplate(data: JsonElement?, properties: List<Property>?): JsonElement {
        return createVariableForTemplate(
            user = this.user,
            data = data,
            properties = properties,
            form = null,
        )
    }

    override suspend fun sendHttpRequest(req: ApiHttpRequest, data: JsonElement?): Result<JsonElement> {
        val variable = this.createVariableForTemplate(data = data)
        val compiledReq = ApiHttpRequest(
            url = req.url?.let { compile(it, variable) },
            method = req.method,
            headers = req.headers?.map { ApiHttpHeader(compile(it.name ?: "", variable), compile(it.value ?: "", variable)) },
            body = req.body?.let { compile(it, variable) },
        )
        return this.httpRequestRepository.request(compiledReq)
    }

    override suspend fun fetchEmbedding(experimentId: String): Result<UIBlock> {
        val configs = this.experimentRepository.fetchExperimentConfigs(experimentId).getOrElse {
            return Result.failure(it)
        }
        val (experimentId, variant) = this.extractVariant(configs = configs, ExperimentKind.EMBED).getOrElse {
            return Result.failure(it)
        }
        val variantId = variant.id ?: return Result.failure(NotFoundException())
        this.trackRepository.trackExperimentEvent(
            TrackExperimentEvent(
            experimentId = experimentId,
            variantId = variantId
        ))
        val componentId = extractComponentId(variant) ?: return Result.failure(NotFoundException())
        val component = this.componentRepository.fetchComponent(experimentId, componentId).getOrElse {
            return Result.failure(it)
        }
        return Result.success(component)
    }

    override suspend fun fetchInAppMessage(trigger: String): Result<UIBlock> {
        val configs = this.experimentRepository.fetchTriggerExperimentConfigs(trigger).getOrElse {
            return Result.failure(it)
        }
        val (experimentId, variant) = this.extractVariant(configs = configs, ExperimentKind.POPUP).getOrElse {
            return Result.failure(it)
        }
        val variantId = variant.id ?: return Result.failure(NotFoundException())
        this.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId = experimentId,
            variantId = variantId
        ))
        val componentId = extractComponentId(variant) ?: return Result.failure(NotFoundException())
        val component = this.componentRepository.fetchComponent(experimentId, componentId).getOrElse {
            return Result.failure(it)
        }
        return Result.success(component)
    }

    override suspend fun fetchRemoteConfig(experimentId: String): Result<String> {
        TODO("Not yet implemented")
    }

    private fun extractVariant(
        configs: ExperimentConfigs,
        kind: ExperimentKind,
    ): Result<Pair<String, ExperimentVariant>> {
        val config = extractExperimentConfig(
            configs = configs,
            properties = { seed -> this.user.toUserProperties(seed) },
            records = { _ -> emptyList() }
        ) ?: return Result.failure(NotFoundException())
        val experimentId = config.id ?: return Result.failure(NotFoundException())
        if (config.kind != kind) return Result.failure(NotFoundException())

        val normalizedUserRnd = this.user.getNormalizedUserRnd(config.seed)
        val variant = extractExperimentVariant(
            config = config,
            normalizedUserRnd = normalizedUserRnd
        ) ?: return Result.failure(NotFoundException())

        return Result.success(experimentId to variant)
    }

}
