//
//  experiment.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/08/24.
//

import Foundation

func extractComponentId(variant: ExperimentVariant) -> String? {
    guard let configs = variant.configs else {
        return nil
    }
    if configs.count == 0 {
        return nil
    }
    let id = configs.first
    return id?.value
}

/**
    normalizedUsrRnd should be in [0, 1]
 */
func extractExperimentVariant(config: ExperimentConfig, normalizedUsrRnd: Double) -> ExperimentVariant? {
    guard let baseline = config.baseline else {
        return nil
    }

    guard let variants = config.variants else {
        return baseline
    }

    if variants.count == 0 {
        return baseline
    }

    let baselineWeight = baseline.weight ?? 1
    var weights = [baselineWeight]
    var weightSum = baselineWeight
    for variant in variants {
        let variantWeight = variant.weight ?? 1
        weights.append(variantWeight)
        weightSum += variantWeight
    }

    // here is calculation of the picking from the probability.
    // X is selected when p_X(x) >= F_X(x)
    // where F_X(x) := Integral p_X(t)dt, the definition of comulative distribution function
    var comulativeDistributionValue: Double = 0.0
    var selectedVariantIndex: Int = 0
    for (index, weight) in weights.enumerated() {
        let probability: Double = Double(weight) / Double(weightSum)
        comulativeDistributionValue += probability

        if comulativeDistributionValue >= normalizedUsrRnd {
            selectedVariantIndex = index
            break
        }
    }

    if selectedVariantIndex == 0 {
        return baseline
    }

    if variants.count > selectedVariantIndex - 1 {
        return variants[selectedVariantIndex - 1]
    }
    return nil
}

func extractExperimentConfigMatchedToProperties(
    configs: ExperimentConfigs,
    properties: (_ seed: Int) -> [UserProperty],
    isNotInFrequency: (_ experimentId: String, _ frequency: ExperimentFrequency?) -> Bool,
    isMatchedToUserEventFrequencyConditions: (_ conditions: [UserEventFrequencyCondition]?) -> Bool
) -> ExperimentConfig? {
    guard let configs = configs.configs else {
        return nil
    }
    if configs.count == 0 {
        return nil
    }
    let now = getCurrentDate()
    return configs.first { config in
        if let startedAt = config.startedAt {
            if let startedAt = parseDateTime(startedAt) {
                if now.compare(startedAt) == ComparisonResult.orderedAscending {
                    return false
                }
            }
        }
        if let endedAt = config.endedAt {
            if let endedAt = parseDateTime(endedAt) {
                if now.compare(endedAt) == ComparisonResult.orderedDescending {
                    return false
                }
            }
        }

        guard let distribution = config.distribution else {
            return true
        }
        let experimentId = config.id ?? ""
        return isNotInFrequency(experimentId, config.frequency) && isMatchedToUserEventFrequencyConditions(config.eventFrequencyConditions) && isInDistribution(distribution: distribution, properties: properties(config.seed ?? 0))
    }
}

func isInDistribution(distribution: [ExperimentCondition], properties: [UserProperty]) -> Bool {
    let props = Dictionary(uniqueKeysWithValues: properties.map({ property in
        return (property.name, property)
    }))
    let foundNotMatched = distribution.first { condition in
        guard let propKey = condition.property else {
            return true
        }
        guard let conditionValue = condition.value else {
            return true
        }
        guard let op = condition.operator else {
            return true
        }
        guard let prop = props[propKey] else {
            return true
        }
        return !comparePropWithConditionValue(prop: prop, asType: condition.asType, value: conditionValue, op: ConditionOperator(rawValue: op) ?? .Equal)
    }
    return foundNotMatched == nil
}

