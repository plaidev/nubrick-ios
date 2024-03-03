package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.data.user.UserPropertyType
import com.nativebrik.sdk.data.user.getCurrentDate
import com.nativebrik.sdk.schema.ConditionOperator
import com.nativebrik.sdk.schema.ExperimentCondition
import com.nativebrik.sdk.schema.ExperimentConfig
import com.nativebrik.sdk.schema.ExperimentConfigs
import com.nativebrik.sdk.schema.ExperimentVariant
import com.nativebrik.sdk.schema.VariantConfig
import org.junit.Assert
import org.junit.Test

class ExtractionUnitTest {
    @Test
    fun extractComponentId_shouldWork() {
        Assert.assertEquals("hello", extractComponentId(ExperimentVariant(configs = listOf(
            VariantConfig(value = "hello")
        ))))
    }

    @Test
    fun extractExperimentVariant_shouldExtractVariantProbabilistically() {
        val config = ExperimentConfig(
            baseline = ExperimentVariant(id = "1", weight = 1), // 0.25
            variants = listOf(
                ExperimentVariant(id = "2", weight = 1), // 0.5
                ExperimentVariant(id = "3", weight = 1), // 0.75
                ExperimentVariant(id = "4", weight = 1), // 1.0
            )
        )

        Assert.assertEquals("1", extractExperimentVariant(config, 0.24)?.id)
        Assert.assertEquals("2", extractExperimentVariant(config, 0.48)?.id)
        Assert.assertEquals("3", extractExperimentVariant(config, 0.74)?.id)
        Assert.assertEquals("4", extractExperimentVariant(config, 0.99)?.id)
    }

    @Test
    fun extractExperimentVariant_shouldWorkWithoutVariants() {
        val config = ExperimentConfig(
            baseline = ExperimentVariant(id = "1", weight = 1), // 0.25
        )
        Assert.assertEquals("1", extractExperimentVariant(config, 0.24)?.id)
    }

    @Test
    fun extractExperimentConfig_shouldWork() {
        val properties: (seed: Int?) -> List<UserProperty> = {
            emptyList()
        }
        val configs = ExperimentConfigs(
            configs = listOf(
                ExperimentConfig(
                    "1",
                    distribution = emptyList()
                )
            )
        )
        Assert.assertEquals("1", extractExperimentConfig(configs, properties) { _, _ -> true }?.id)
    }

    @Test
    fun extractExperimentConfig_shouldFilterOnlyRunningConfig() {
        val properties: (seed: Int?) -> List<UserProperty> = {
            emptyList()
        }
        val configs = ExperimentConfigs(
            configs = listOf(
                ExperimentConfig(
                    "1",
                    startedAt = getCurrentDate().plusDays(1),
                ),
                ExperimentConfig("2",
                    startedAt = getCurrentDate().minusDays(1),
                    endedAt = getCurrentDate().minusDays(1)
                ),
                ExperimentConfig(
                    "running",
                    startedAt = getCurrentDate().minusDays(1),
                    endedAt = getCurrentDate().plusDays(1),
                )
            )
        )
        Assert.assertEquals("running", extractExperimentConfig(configs, properties) { _, _ -> true }?.id)
    }

    @Test
    fun isInDistributionTarget_shouldBeTrueWhenEmptyDistribution() {
        val properties: List<UserProperty> = emptyList()
        Assert.assertEquals(true, isInDistributionTarget(null, properties))
    }

    @Test
    fun isInDistributionTarget_shouldBeTrueWhenThereCorrectDistribution() {
        val properties: List<UserProperty> = listOf(
            UserProperty(
                name = "name",
                value = "Nativebrik",
                type = UserPropertyType.STRING
            ),
            UserProperty(
                name = "id",
                value = "XXX",
                type = UserPropertyType.STRING
            )
        )
        val distribution: List<ExperimentCondition> = listOf(
            ExperimentCondition(
                property = "name",
                operator = ConditionOperator.Equal.name,
                value = "Nativebrik"
            ),
            ExperimentCondition(
                property = "id",
                operator = ConditionOperator.Equal.name,
                value = "XXX"
            ),
        )
        Assert.assertEquals(true, isInDistributionTarget(distribution, properties))
    }

    @Test
    fun isInDistributionTarget_shouldBeFalseWhenThereIncorrectDistribution() {
        val properties: List<UserProperty> = listOf(
            UserProperty(
                name = "name",
                value = "Nativebrik",
                type = UserPropertyType.STRING
            ),
            UserProperty(
                name = "id",
                value = "XXX",
                type = UserPropertyType.STRING
            )
        )
        val distribution: List<ExperimentCondition> = listOf(
            ExperimentCondition(
                property = "name",
                operator = ConditionOperator.Equal.name,
                value = "Nativebrik"
            ),
            ExperimentCondition(
                property = "id",
                operator = ConditionOperator.Equal.name,
                value = "YYY"
            ),
        )
        Assert.assertEquals(false, isInDistributionTarget(distribution, properties))
    }
}