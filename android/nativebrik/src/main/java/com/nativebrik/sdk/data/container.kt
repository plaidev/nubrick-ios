package com.nativebrik.sdk.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import com.nativebrik.sdk.Config
import com.nativebrik.sdk.data.database.DatabaseRepository
import com.nativebrik.sdk.data.database.DatabaseRepositoryImpl
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

internal interface Container {
    fun createVariableForTemplate(data: JsonElement? = null, properties: List<Property>? = null): JsonElement

    fun getFormValue(key: String): FormValue?
    fun setFormValue(key: String, value: FormValue)

    suspend fun sendHttpRequest(req: ApiHttpRequest, variable: JsonElement? = null): Result<JsonElement>
    suspend fun fetchEmbedding(experimentId: String, componentId: String? = null): Result<UIBlock>
    suspend fun fetchInAppMessage(trigger: String): Result<UIBlock>
    suspend fun fetchRemoteConfig(experimentId: String): Result<ExperimentVariant>
}

internal class ContainerImpl(
    private val config: Config,
    private val user: NativebrikUser,
    private val db: SQLiteDatabase,
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
    private val formRepository: FormRepository by lazy {
        FormRepositoryImpl()
    }
    private val databaseRepository: DatabaseRepository by lazy {
        DatabaseRepositoryImpl(db)
    }

    override fun createVariableForTemplate(data: JsonElement?, properties: List<Property>?): JsonElement {
        return createVariableForTemplate(
            user = this.user,
            data = data,
            properties = properties,
            form = formRepository.getFormData(),
            projectId = config.projectId,
        )
    }

    override fun getFormValue(key: String): FormValue? {
        return this.formRepository.getValue(key)
    }

    override fun setFormValue(key: String, value: FormValue) {
        this.formRepository.setValue(key, value)
    }

    override suspend fun sendHttpRequest(req: ApiHttpRequest, variable: JsonElement?): Result<JsonElement> {
        val compiledReq = ApiHttpRequest(
            url = req.url?.let { compile(it, variable) },
            method = req.method,
            headers = req.headers?.map { ApiHttpHeader(compile(it.name ?: "", variable), compile(it.value ?: "", variable)) },
            body = req.body?.let { compile(it, variable) },
        )
        return this.httpRequestRepository.request(compiledReq)
    }

    override suspend fun fetchEmbedding(experimentId: String, componentId: String?): Result<UIBlock> {
        if (componentId != null) {
            val component = this.componentRepository.fetchComponent(experimentId, componentId).getOrElse {
                return Result.failure(it)
            }
            return Result.success(component)
        }

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
        // send the user track event and save it to database
        this.trackRepository.trackEvent(TrackUserEvent(trigger))
        this.databaseRepository.appendUserEvent(trigger)

        // fetch config from cdn
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

    override suspend fun fetchRemoteConfig(experimentId: String): Result<ExperimentVariant> {
        val configs = this.experimentRepository.fetchExperimentConfigs(experimentId).getOrElse {
            return Result.failure(it)
        }
        val (experimentId, variant) = this.extractVariant(configs = configs, ExperimentKind.CONFIG).getOrElse {
            return Result.failure(it)
        }
        val variantId = variant.id ?: return Result.failure(NotFoundException())
        this.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId = experimentId,
            variantId = variantId
        ))
        return Result.success(variant)
    }

    private fun extractVariant(
        configs: ExperimentConfigs,
        kind: ExperimentKind,
    ): Result<Pair<String, ExperimentVariant>> {
        val config = extractExperimentConfig(
            configs = configs,
            properties = { seed -> this.user.toUserProperties(seed) },
            isNotInFrequency = { experimentId, frequency ->
                this.databaseRepository.isNotInFrequency(experimentId, frequency)
            }
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
