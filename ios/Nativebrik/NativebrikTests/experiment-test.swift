//
//  experiment-test.swift
//  NativebrikTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
@testable import Nativebrik

final class ExperimentTests: XCTestCase {
    func testExtractComponentIdShouldReturnTheFirst() throws {
        let expected = "HELLO_WORLD"
        let actual = extractComponentId(variant: ExperimentVariant(
            configs: [VariantConfig(value: expected), VariantConfig()]
        ))
        XCTAssertEqual(expected, actual)
    }
    
    func testExtractComponentIdShouldReturnNil() throws {
        let expected: String? = nil
        let actual = extractComponentId(variant: ExperimentVariant(
            configs: []
        ))
        XCTAssertEqual(expected, actual)
    }
    
    func testExtractExperimentVariantShouldFollowWeightedProbability() throws {
        let config = ExperimentConfig(
            baseline: ExperimentVariant( // prob := 2 / 10 = 0.2
                id: "baseline",
                weight: 2
            ),
            variants: [
                ExperimentVariant( // prob := 3 / 10 = 0.3
                    
                    weight: 3
                ),
                ExperimentVariant( // prob := 5 / 10 = 0.5
                    weight: 5
                ),
            ]
        )
        
        var baseline = extractExperimentVariant(config: config, normalizedUsrRnd: 0.0)
        XCTAssertEqual(baseline?.id, config.baseline?.id)
        baseline = extractExperimentVariant(config: config, normalizedUsrRnd: 0.2)
        XCTAssertEqual(baseline?.id, config.baseline?.id)
        
        var variant1 = extractExperimentVariant(config: config, normalizedUsrRnd: 0.21)
        XCTAssertEqual(variant1?.id, config.variants?[0].id)
        variant1 = extractExperimentVariant(config: config, normalizedUsrRnd: 0.5)
        XCTAssertEqual(variant1?.id, config.variants?[0].id)
        
        var variant2 = extractExperimentVariant(config: config, normalizedUsrRnd: 0.51)
        XCTAssertEqual(variant2?.id, config.variants?[1].id)
        variant2 = extractExperimentVariant(config: config, normalizedUsrRnd: 1)
        XCTAssertEqual(variant2?.id, config.variants?[1].id)
    }
    
    func testExtractExperimentVariantShouldReturnBaseline() throws {
        let config = ExperimentConfig(
            baseline: ExperimentVariant( // prob := 2 / 10 = 0.2
                id: "baseline",
                weight: 2
            ),
            variants: []
        )
        let baseline = extractExperimentVariant(config: config, normalizedUsrRnd: 1.0)
        XCTAssertEqual(baseline?.id, config.baseline?.id)
    }
    
    func testIsInDistributionShouldBeTrue() throws {
        let userId = "hello"
        let userRnd = "50"
        let distribution: [ExperimentCondition] = [
            ExperimentCondition(property: "userId", operator: ConditionOperator.Equal.rawValue, value: userId),
            ExperimentCondition(property: "userRnd", operator: ConditionOperator.LessThanOrEqual.rawValue, value: "100")
        ]
        let props: [UserProperty] = [
            UserProperty(name: "userId", value: userId, type: .STRING),
            UserProperty(name: "userRnd", value: userRnd, type: .INTEGER),
            UserProperty(name: "else", value: "world", type: .STRING),
        ]
        
        let actual = isInDistribution(distribution: distribution, properties: props)
        XCTAssertTrue(actual)
    }
    
    func testIsInDistributionShouldBeTrueWhenZeroConditions() throws {
        let userId = "hello"
        let distribution: [ExperimentCondition] = []
        let props: [UserProperty] = [
            UserProperty(name: "userId", value: userId, type: .STRING),
        ]
        
        let actual = isInDistribution(distribution: distribution, properties: props)
        XCTAssertTrue(actual)
    }
    
    func testIsInDistributionShouldBeFalse() throws {
        let userId = "hello"
        let userRnd = "50"
        let distribution: [ExperimentCondition] = [
            ExperimentCondition(property: "userId", operator: ConditionOperator.Equal.rawValue, value: userId),
            ExperimentCondition(property: "userRnd", operator: ConditionOperator.LessThanOrEqual.rawValue, value: "30")
        ]
        let props: [UserProperty] = [
            UserProperty(name: "userId", value: userId, type: .STRING),
            UserProperty(name: "userRnd", value: userRnd, type: .INTEGER),
            UserProperty(name: "else", value: "world", type: .STRING),
        ]
        
        let actual = isInDistribution(distribution: distribution, properties: props)
        XCTAssertFalse(actual)
    }
    
    func testIsNotInFrequencyShouldBeTrueWhenZeroRecords() throws {
        let frequency = ExperimentFrequency()
        let records: [ExperimentHistoryRecord] = []
        let actual = isNotInFrequency(frequency: frequency, records: records)
        XCTAssertTrue(actual)
    }
    
    func testIsNotInFrequencyShouldBeTrueWhenNilFrequency() throws {
        let today = getToday()
        let morning = today.timeIntervalSince1970 + 5000
        let morning2 = today.timeIntervalSince1970 + 10000
        let records: [ExperimentHistoryRecord] = [morning, morning2]
        let actual = isNotInFrequency(frequency: nil, records: records)
        XCTAssertTrue(actual)
    }

    
    func testIsNotInFrequencyShouldBeFalseWhenItsIndifinetePeriod() throws {
        let today = getToday()
        let morning = today.timeIntervalSince1970 + 50000
        let frequency = ExperimentFrequency()
        let records: [ExperimentHistoryRecord] = [morning]
        let actual = isNotInFrequency(frequency: frequency, records: records)
        XCTAssertFalse(actual)
    }

    func testIsNotInFrequencyWhenItShowsOnlyOneTimeInTwoDays() throws {
        let today = getToday()
        let morning = today.timeIntervalSince1970 + 5000
        let morning2 = today.timeIntervalSince1970 + 10000
        let yesterday = today.timeIntervalSince1970 - Double(1 * 24 * 60 * 60) + 5000
        let twoDaysAgo = today.timeIntervalSince1970 - Double(2 * 24 * 60 * 60) + 5000
        let threeDaysAgo = today.timeIntervalSince1970 - Double(3 * 24 * 60 * 60) + 5000
        let frequency = ExperimentFrequency(
            period: 2,
            unit: .DAY
        )
        
        var actual = isNotInFrequency(frequency: frequency, records: [twoDaysAgo])
        XCTAssertTrue(actual)
        
        actual = isNotInFrequency(frequency: frequency, records: [yesterday, twoDaysAgo])
        XCTAssertFalse(actual)
        
        actual = isNotInFrequency(frequency: frequency, records: [twoDaysAgo, threeDaysAgo])
        XCTAssertTrue(actual)
        
        actual = isNotInFrequency(frequency: frequency, records: [yesterday, twoDaysAgo, threeDaysAgo])
        XCTAssertFalse(actual)
    }
    
    func testExtractExperimentConfigMatchedToPropertiesShouldReturnNilWhenItsZeroConfig() throws {
        let actual = extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: [])) { seed in
            return []
        } records: { experimentId in
            return []
        }
        XCTAssertNil(actual)
    }
    
    func testExtractExperimentConfigMatchedToProperties() throws {
        let userId = "hello"
        let userRnd = "50"
        let distribution: [ExperimentCondition] = [
            ExperimentCondition(property: "userId", operator: ConditionOperator.Equal.rawValue, value: userId),
            ExperimentCondition(property: "userRnd", operator: ConditionOperator.LessThanOrEqual.rawValue, value: "100")
        ]
        let props: [UserProperty] = [
            UserProperty(name: "userId", value: userId, type: .STRING),
            UserProperty(name: "userRnd", value: userRnd, type: .INTEGER),
            UserProperty(name: "else", value: "world", type: .STRING),
        ]
        
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(
                    id: "id_0",
                    distribution: [
                        ExperimentCondition(property: "userId", operator: ConditionOperator.NotEqual.rawValue, value: userId),
                    ]
                ),
                ExperimentConfig(
                    id: "id_with_distribution",
                    distribution: distribution
                )
            ]
        )

        let actual = extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: configs.configs)) { seed in
            return props
        } records: { experimentId in
            return []
        }
        
        XCTAssertEqual(configs.configs?[1].id, actual?.id)
    }

}


final class CompareTests: XCTestCase {
    func testComparePropWithConditionValue() throws {
        let userId = "hello world"
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userId", value: userId, type: .STRING), value: userId, op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userRnd", value: "40", type: .INTEGER), value: "100", op: .LessThanOrEqual))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "version", value: "4", type: .SEMVER), value: "4.1", op: .LessThanOrEqual))
    }
    
    func testCompareSemverAsComparisonResultWhenOnlyMajorVersions() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1"), .orderedSame)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "2"), .orderedAscending)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "0"), .orderedDescending)
    }
    
    func testCompareSemverAsComparisonResultWhenItsDifferentFormat() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1.0"), .orderedSame)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1.0"), .orderedSame)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1"), .orderedSame)
    }
    
    func testCompareSemverAsComparisonResult() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1"), .orderedDescending)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2"), .orderedDescending)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.2"), .orderedDescending)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.4"), .orderedAscending)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "2"), .orderedAscending)
    }
    
    func testCompareSemver() throws {
        // equal
        XCTAssertTrue(compareSemver(a: "1", b: ["1.0"], op: .Equal))
        XCTAssertFalse(compareSemver(a: "1", b: ["1.0.1"], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .NotEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.0"], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9"], op: .GreaterThan))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1"], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1"], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9"], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1"], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .LessThan))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["0.0.9"], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1"], op: .LessThanOrEqual))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .LessThanOrEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["0.0.9"], op: .LessThanOrEqual))
        
        // in
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1", "2"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["2", "3"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareSemver(a: "1.0", b: [], op: .NotIn))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["2", "3"], op: .NotIn))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1", "2"], op: .NotIn))
        
        // between
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9", "1.0.1"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1", "2"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .Between))
    }
    
    func testCompareString() throws {
        // equal
        XCTAssertTrue(compareString(a: "a", b: ["a"], op: .Equal))
        XCTAssertFalse(compareString(a: "a", b: ["b"], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareString(a: "a", b: ["b"], op: .NotEqual))
        XCTAssertFalse(compareString(a: "a", b: ["a"], op: .NotEqual))

        // in
        XCTAssertTrue(compareString(a: "a", b: ["a", "b"], op: .In))
        XCTAssertFalse(compareString(a: "a", b: ["b", "c"], op: .In))
        XCTAssertFalse(compareString(a: "a", b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareString(a: "a", b: [], op: .NotIn))
        XCTAssertTrue(compareString(a: "a", b: ["b", "c"], op: .NotIn))
        XCTAssertFalse(compareString(a: "a", b: ["a", "b"], op: .NotIn))
    }
    
    func testCompareStringWithRegex() throws {
        XCTAssertTrue(compareString(a: "hello-world_11", b: ["[a-zA-Z0-9-_]+"], op: .Regex))
        XCTAssertFalse(compareString(a: "hello", b: ["[^a-zA-Z-_]"], op: .Regex))
    }
    
    func testCompareStringWithRegexShouldBeFalseWhenThePatternIsWrong() throws {
        XCTAssertFalse(compareString(a: "+", b: ["+"], op: .Regex))
    }
    
    func testCompareDouble() throws {
        // equal
        XCTAssertTrue(compareDouble(a: 0, b: [0], op: .Equal))
        XCTAssertFalse(compareDouble(a: 0, b: [1], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareDouble(a: 0, b: [1], op: .NotEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [1], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareDouble(a: 1, b: [0], op: .GreaterThan))
        XCTAssertFalse(compareDouble(a: 1, b: [1], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareDouble(a: 1, b: [1], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareDouble(a: 1, b: [0], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [2], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareDouble(a: 1, b: [2], op: .LessThan))
        XCTAssertFalse(compareDouble(a: 1, b: [0], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareDouble(a: 1, b: [1], op: .LessThanOrEqual))
        XCTAssertTrue(compareDouble(a: 1, b: [2], op: .LessThanOrEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [0], op: .LessThanOrEqual))

        // in
        XCTAssertTrue(compareDouble(a: 1, b: [0, 1], op: .In))
        XCTAssertFalse(compareDouble(a: 1, b: [2, 3], op: .In))
        XCTAssertFalse(compareDouble(a: 1, b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareDouble(a: 1, b: [], op: .NotIn))
        XCTAssertTrue(compareDouble(a: 1, b: [2, 3], op: .NotIn))
        XCTAssertFalse(compareDouble(a: 1, b: [1, 2], op: .NotIn))
        
        // between
        XCTAssertTrue(compareDouble(a: 5, b: [0, 10], op: .Between))
        XCTAssertFalse(compareDouble(a: 5, b: [10, 20], op: .Between))
        XCTAssertFalse(compareDouble(a: 5, b: [], op: .Between))
    }
    
    func testCompareInteger() throws {
        // equal
        XCTAssertTrue(compareInteger(a: 0, b: [0], op: .Equal))
        XCTAssertFalse(compareInteger(a: 0, b: [1], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareInteger(a: 0, b: [1], op: .NotEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [1], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareInteger(a: 1, b: [0], op: .GreaterThan))
        XCTAssertFalse(compareInteger(a: 1, b: [1], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareInteger(a: 1, b: [1], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareInteger(a: 1, b: [0], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [2], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareInteger(a: 1, b: [2], op: .LessThan))
        XCTAssertFalse(compareInteger(a: 1, b: [0], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareInteger(a: 1, b: [1], op: .LessThanOrEqual))
        XCTAssertTrue(compareInteger(a: 1, b: [2], op: .LessThanOrEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [0], op: .LessThanOrEqual))

        // in
        XCTAssertTrue(compareInteger(a: 1, b: [0, 1], op: .In))
        XCTAssertFalse(compareInteger(a: 1, b: [2, 3], op: .In))
        XCTAssertFalse(compareInteger(a: 1, b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareInteger(a: 1, b: [], op: .NotIn))
        XCTAssertTrue(compareInteger(a: 1, b: [2, 3], op: .NotIn))
        XCTAssertFalse(compareInteger(a: 1, b: [1, 2], op: .NotIn))
        
        // between
        XCTAssertTrue(compareInteger(a: 5, b: [0, 10], op: .Between))
        XCTAssertFalse(compareInteger(a: 5, b: [10, 20], op: .Between))
        XCTAssertFalse(compareInteger(a: 5, b: [], op: .Between))
    }
    
}
