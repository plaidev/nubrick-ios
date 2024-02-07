package com.nativebrik.sdk.data.extraction

import com.nativebrik.sdk.data.user.UserProperty
import com.nativebrik.sdk.schema.ConditionOperator
import com.nativebrik.sdk.schema.ExperimentCondition
import com.nativebrik.sdk.schema.ExperimentConfig
import com.nativebrik.sdk.schema.ExperimentConfigs
import com.nativebrik.sdk.schema.ExperimentFrequency
import com.nativebrik.sdk.schema.ExperimentVariant

fun extractComponentId(variant: ExperimentVariant): String? {
    val configs = variant.configs?.let { it } ?: return null
    if (configs.isEmpty()) return null
    val id = configs.firstOrNull()
    return id?.value
}

fun extractExperimentVariant(config: ExperimentConfig, normalizedUserRnd: Double): ExperimentVariant? {
    val baseline = config.baseline?.let { it } ?: return null
    val variants = config.variants?.let { it } ?: return baseline
    if (variants.isEmpty()) return baseline

    val baselineWeight = baseline.weight ?: 1
    var weights: MutableList<Int> = mutableListOf(baselineWeight)
    variants.forEach {
        val weight = it.weight ?: 1
        weights.add(weight)
    }
    var weightSum = weights.sum()

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

fun extractExperimentConfig(
    configs: ExperimentConfigs,
    properties: (seed: Int?) -> List<UserProperty>,
    records: (experimentId: String) -> List<Double>,
): ExperimentConfig? {
    val configs = configs.configs?.let { it } ?: return null
    if (configs.isEmpty()) return null

    return configs.firstOrNull { config ->
        val distribution = config.distribution
        if (distribution == null) {
            true
        }
        val experimentId = config.id ?: ""
        isNotInFrequency(
            frequency = config.frequency,
            records = records(experimentId),
        ) && isInDistributionTarget(
            distribution = config.distribution,
            properties = properties(config.seed),
        )
    }
}

fun isInDistributionTarget(distribution: List<ExperimentCondition>?, properties: List<UserProperty>): Boolean {
    val props = properties.associateBy { property -> property.name }
    val foundNotMatched = distribution?.firstOrNull { condition ->
        val propKey = condition.property ?: return@firstOrNull true
        val conditionValue = condition.value ?: return@firstOrNull true
        val op = condition.operator ?: return@firstOrNull true
        val prop = props[propKey] ?: return@firstOrNull true
        !comparePropWithConditionValue(
            prop = prop,
            value = conditionValue,
            op = ConditionOperator.valueOf(op)
        )
    }
    return foundNotMatched == null
}

fun isNotInFrequency(frequency: ExperimentFrequency?, records: List<Double>): Boolean {
    return true
}

