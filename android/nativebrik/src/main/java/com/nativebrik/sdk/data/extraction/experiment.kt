package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.data.user.getCurrentDate
import com.nativebrik.sdk.schema.ConditionOperator
import com.nativebrik.sdk.schema.ExperimentCondition
import com.nativebrik.sdk.schema.ExperimentConfig
import com.nativebrik.sdk.schema.ExperimentConfigs
import com.nativebrik.sdk.schema.ExperimentFrequency
import com.nativebrik.sdk.schema.ExperimentVariant

internal fun extractComponentId(variant: ExperimentVariant): String? {
    val configs = variant.configs ?: return null
    if (configs.isEmpty()) return null
    val id = configs.firstOrNull()
    return id?.value
}

internal fun extractExperimentVariant(config: ExperimentConfig, normalizedUserRnd: Double): ExperimentVariant? {
    val baseline = config.baseline ?: return null
    val variants = config.variants ?: return baseline
    if (variants.isEmpty()) return baseline

    val baselineWeight = baseline.weight ?: 1
    val weights: MutableList<Int> = mutableListOf(baselineWeight)
    variants.forEach {
        val weight = it.weight ?: 1
        weights.add(weight)
    }
    val weightSum = weights.sum()

    // here is calculation of the picking from the probability.
    // X is selected when p_X(x) >= F_X(x)
    // where F_X(x) := Integral p_X(t)dt, the definition of cumulative distribution function
    var cumulativeDistributionValue: Double = 0.0
    var selectedVariantIndex: Int = 0

    for ((index, weight) in weights.withIndex()) {
        val probability: Double = weight.toDouble() / weightSum.toDouble()
        cumulativeDistributionValue += probability
        if (cumulativeDistributionValue >= normalizedUserRnd) {
            selectedVariantIndex = index
            break
        }
    }

    if (selectedVariantIndex == 0) return baseline
    if (variants.count() > selectedVariantIndex - 1) {
        return variants[selectedVariantIndex - 1]
    }
    return null
}

internal fun extractExperimentConfig(
    configs: ExperimentConfigs,
    properties: (seed: Int?) -> List<UserProperty>,
    isNotInFrequency: (experimentId: String, frequency: ExperimentFrequency?) -> Boolean,
): ExperimentConfig? {
    val configs = configs.configs ?: return null
    if (configs.isEmpty()) return null
    val currentDate = getCurrentDate()

    return configs.firstOrNull { config ->
        val startedAt = config.startedAt
        if (startedAt != null) {
            if (currentDate.isBefore(startedAt)) {
                return@firstOrNull false
            }
        }
        val endedAt = config.endedAt
        if (endedAt != null) {
            if (currentDate.isAfter(endedAt)) {
                return@firstOrNull false
            }
        }
        val experimentId = config.id ?: ""
        return@firstOrNull isNotInFrequency(
            experimentId,
            config.frequency,
        ) && isInDistributionTarget(
            distribution = config.distribution,
            properties = properties(config.seed),
        )
    }
}

internal fun isInDistributionTarget(distribution: List<ExperimentCondition>?, properties: List<UserProperty>): Boolean {
    if (distribution == null) return true
    if (distribution.isEmpty()) return true
    val props = properties.associateBy { property -> property.name }
    val foundNotMatched = distribution.firstOrNull { condition ->
        val propKey = condition.property ?: return@firstOrNull true
        val conditionValue = condition.value ?: return@firstOrNull true
        val op = condition.operator ?: return@firstOrNull true
        val prop = props[propKey] ?: return@firstOrNull true
        !comparePropWithConditionValue(
            prop = prop,
            asType = condition.asType,
            value = conditionValue,
            op = ConditionOperator.valueOf(op)
        )
    }
    return foundNotMatched == null
}
