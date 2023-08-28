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
    let id = configs[0]
    return id.value
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

    return variants[selectedVariantIndex - 1]
}

func extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs, properties: (_ seed: Int) -> [EventProperty]) -> ExperimentConfig? {
    guard let configs = configs.configs else {
        return nil
    }
    if configs.count == 0 {
        return nil
    }
    return configs.first { config in
        guard let distribution = config.distribution else {
            return true
        }
        return isInDistribution(distribution: distribution, properties: properties(config.seed ?? 0))
    }
}

func isInDistribution(distribution: [ExperimentCondition], properties: [EventProperty]) -> Bool {
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
        return !comparePropWithConditionValue(prop: prop, value: conditionValue, op: ConditionOperator(rawValue: op) ?? .Equal)
    }
    return foundNotMatched == nil
}

func comparePropWithConditionValue(prop: EventProperty, value: String, op: ConditionOperator) -> Bool {
    let values = value.split(separator: ",")
    switch prop.type {
    case .INTEGER:
        let propValue = Int(prop.value) ?? 0
        let conditionValues = values.map { value in
            return Int(value) ?? 0
        }
        return compareInteger(a: propValue, b: conditionValues, op: op)
    case .STRING:
        let strings: [String] = values.map { value in
            return String(value)
        }
        return compareString(a: prop.value, b: strings, op: op)
    case .TIMESTAMPZ:
        let dateFormatter = DateFormatter()
        let propValue = dateFormatter.date(from: prop.value)?.timeIntervalSince1970 ?? 0
        let conditionValues = values.map { value in
            return dateFormatter.date(from: prop.value)?.timeIntervalSince1970 ?? 0
        }
        return compareDouble(a: propValue, b: conditionValues, op: op)
    default:
        return false
    }
}

func compareInteger(a: Int, b: [Int], op: ConditionOperator) -> Bool {
    switch op {
    case .Equal:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    case .NotEqual:
        if b.count == 0 {
            return false
        }
        return a != b[0]
    case .GreaterThan:
        if b.count == 0 {
            return false
        }
        return a > b[0]
    case .GreaterThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a >= b[0]
    case .LessThan:
        if b.count == 0 {
            return false
        }
        return a < b[0]
    case .LessThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a <= b[0]
    case .In:
        return b.contains { value in
            return value == a
        }
    case .NotIn:
        return !b.contains { value in
            return value == a
        }
    default:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    }
}

func compareDouble(a: Double, b: [Double], op: ConditionOperator) -> Bool {
    switch op {
    case .Equal:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    case .NotEqual:
        if b.count == 0 {
            return false
        }
        return a != b[0]
    case .GreaterThan:
        if b.count == 0 {
            return false
        }
        return a > b[0]
    case .GreaterThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a >= b[0]
    case .LessThan:
        if b.count == 0 {
            return false
        }
        return a < b[0]
    case .LessThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a <= b[0]
    case .In:
        return b.contains { value in
            return value == a
        }
    case .NotIn:
        return !b.contains { value in
            return value == a
        }
    default:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    }
}

func compareString(a: String, b: [String], op: ConditionOperator) -> Bool {
    switch op {
    case .Equal:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    case .NotEqual:
        if b.count == 0 {
            return false
        }
        return a != b[0]
    case .GreaterThan:
        if b.count == 0 {
            return false
        }
        return a > b[0]
    case .GreaterThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a >= b[0]
    case .LessThan:
        if b.count == 0 {
            return false
        }
        return a < b[0]
    case .LessThanOrEqual:
        if b.count == 0 {
            return false
        }
        return a <= b[0]
    case .In:
        return b.contains { value in
            return value == a
        }
    case .NotIn:
        return !b.contains { value in
            return value == a
        }
    default:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    }
}
