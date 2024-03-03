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

func extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs, properties: (_ seed: Int) -> [UserProperty], records: (_ experimentId: String) -> [ExperimentHistoryRecord]) -> ExperimentConfig? {
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
        let experimentId = config.id ?? ""
        return isNotInFrequency(frequency: config.frequency, records: records(experimentId)) && isInDistribution(distribution: distribution, properties: properties(config.seed ?? 0))
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
        return !comparePropWithConditionValue(prop: prop, value: conditionValue, op: ConditionOperator(rawValue: op) ?? .Equal)
    }
    return foundNotMatched == nil
}

func isNotInFrequency(frequency: ExperimentFrequency?, records: [ExperimentHistoryRecord]) -> Bool {
    guard let frequency = frequency else {
        return true
    }
    let time = 1
    guard let period = frequency.period else {
        return records.count < time
    }
    let unit = frequency.unit ?? .DAY
    switch unit {
    case .DAY, .unknown:
        let today = getToday()
        let from = today.timeIntervalSince1970 - Double((period - 1) * 24 * 60 * 60)
        var count = 0
        for timestamp in records {
            if timestamp > from {
                count += 1
            } else {
                break
            }
        }
        return count < time
    }
}

func comparePropWithConditionValue(prop: UserProperty, value: String, op: ConditionOperator) -> Bool {
    let values = value.split(separator: ",")
    switch prop.type {
    case .INTEGER:
        let propValue = Int(prop.value) ?? 0
        let conditionValues = values.map { value in
            return Int(value) ?? 0
        }
        return compareInteger(a: propValue, b: conditionValues, op: op)
    case .DOUBLE:
        let propValue = Double(prop.value) ?? 0
        let conditionValues = values.map { value in
            return Double(value) ?? 0
        }
        return compareDouble(a: propValue, b: conditionValues, op: op)
    case .STRING:
        let strings: [String] = values.map { value in
            return String(value)
        }
        return compareString(a: prop.value, b: strings, op: op)
    case .SEMVER:
        let strings: [String] = values.map { value in
            return String(value)
        }
        return compareSemver(a: prop.value, b: strings, op: op)
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
    case .Between:
        if b.count != 2 {
            return false
        }
        return b[0] <= a && a <= b[1]
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
    case .Between:
        if b.count != 2 {
            return false
        }
        return b[0] <= a && a <= b[1]
    default:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    }
}

func compareString(a: String, b: [String], op: ConditionOperator) -> Bool {
    switch op {
    case .Regex:
        if b.count == 0 {
            return false
        }
        return containsPattern(a, b[0])
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
    case .Between:
        if b.count != 2 {
            return false
        }
        return b[0] <= a && a <= b[1]
    default:
        if b.count == 0 {
            return false
        }
        return a == b[0]
    }
}

func compareSemver(a: String, b: [String], op: ConditionOperator) -> Bool {
    switch op {
    case .Equal:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == .orderedSame
    case .NotEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) != .orderedSame
    case .GreaterThan:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == .orderedDescending
    case .GreaterThanOrEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) != .orderedAscending
    case .LessThan:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == .orderedAscending
    case .LessThanOrEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) != .orderedDescending
    case .In:
        return b.contains { value in
            return compareSemverAsComparisonResult(a, b[0]) == .orderedSame
        }
    case .NotIn:
        return !b.contains { value in
            return compareSemverAsComparisonResult(a, b[0]) == .orderedSame
        }
    case .Between:
        if b.count != 2 {
            return false
        }
        let left = compareSemverAsComparisonResult(a, b[0])
        let right = compareSemverAsComparisonResult(a, b[1])
        return left != .orderedAscending && right != .orderedDescending
    default:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == .orderedSame
    }
}

func compareSemverAsComparisonResult(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let versionDelimiter = "."

    var lhsComponents = lhs.components(separatedBy: versionDelimiter)
    var rhsComponents = rhs.components(separatedBy: versionDelimiter)

    let zeroDiff = lhsComponents.count - rhsComponents.count

    if zeroDiff == 0 {
        // Same format, compare normally
        return lhs.compare(rhs, options: .numeric)
    } else {
        // append zeros to suffix to compare with the same format v'x' -> v'x.0.0'
        let zeros = Array(repeating: "0", count: abs(zeroDiff))
        if zeroDiff > 0 {
            rhsComponents.append(contentsOf: zeros)
        } else {
            lhsComponents.append(contentsOf: zeros)
        }
        return lhsComponents.joined(separator: versionDelimiter)
            .compare(rhsComponents.joined(separator: versionDelimiter), options: .numeric)
    }
}

func containsPattern(_ input: String, _ pattern: String) -> Bool {
    if #available(iOS 16.0, *) {
        do {
            let regex = try Regex(pattern)
            return input.contains(regex)
        } catch {
            return false
        }
    } else {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let count = regex.numberOfMatches(in: input, range: NSRange(location: 0, length: input.utf16.count))
            return count > 0
        } catch {
            return false
        }
    }
}
