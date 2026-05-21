//
//  extractionTests.swift
//  NubrickTests
//
//  Created by Takuma Jimbo on 2025/08/01.
//

import XCTest
@testable import NubrickLocal

final class ExtractionTests: XCTestCase {
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
    
    func testExtractExperimentConfigMatchedToPropertiesShouldReturnNilWhenItsZeroConfig() async throws {
        let actual = await extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: []), kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        XCTAssertNil(actual)
    }
    
    func testExtractExperimentConfigMatchedToProperties() async throws {
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
                    kind: .POPUP,
                    distribution: [
                        ExperimentCondition(property: "userId", operator: ConditionOperator.NotEqual.rawValue, value: userId),
                    ]
                ),
                ExperimentConfig(
                    id: "id_with_distribution",
                    kind: .POPUP,
                    distribution: distribution
                )
            ]
        )

        let actual = await extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: configs.configs), kinds: [.POPUP]) { seed in
            return props
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        
        XCTAssertEqual(configs.configs?[1].id, actual?.id)
    }
    
    func testExtractExperimentConfigMatchedToPropertiesWhenItsScheduled() async throws {
        let now = getCurrentDate()
        let dayM1 = now.addingTimeInterval(-1000)
        let day1 = now.addingTimeInterval(1000)
        let day2 = now.addingTimeInterval(2000)
        
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(
                    id: "id_0",
                    kind: .POPUP,
                    startedAt: day1.ISO8601Format()
                ),
                ExperimentConfig(
                    id: "id_1",
                    kind: .POPUP,
                    endedAt: dayM1.ISO8601Format()
                ),
                ExperimentConfig(
                    id: "now",
                    kind: .POPUP,
                    startedAt: dayM1.ISO8601Format(),
                    endedAt: day2.ISO8601Format()
                ),
            ]
        )
        
        let actual = await extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: configs.configs), kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        
        XCTAssertEqual("now", actual?.id)
    }

    func testExtractExperimentConfigMatchedToPropertiesSelectsHighestPriority() async throws {
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(id: "low", kind: .POPUP, priority: 1),
                ExperimentConfig(id: "high", kind: .POPUP, priority: 10),
                ExperimentConfig(id: "mid", kind: .POPUP, priority: 5),
            ]
        )

        let actual = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }

        XCTAssertEqual("high", actual?.id)
    }

    func testExtractExperimentConfigMatchedToPropertiesTiedPriorityPrefersLatestStartDate() async throws {
        let now = getCurrentDate()
        let earlier = now.addingTimeInterval(-2000)
        let later = now.addingTimeInterval(-1000)

        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(id: "earlier", kind: .POPUP, startedAt: earlier.ISO8601Format(), priority: 5),
                ExperimentConfig(id: "later", kind: .POPUP, startedAt: later.ISO8601Format(), priority: 5),
            ]
        )

        let actual = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }

        XCTAssertEqual("later", actual?.id)
    }

    func testExtractExperimentConfigMatchedToPropertiesNilPriorityRankedLowest() async throws {
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(id: "no_priority", kind: .POPUP),
                ExperimentConfig(id: "has_priority", kind: .POPUP, priority: 1),
            ]
        )

        let actual = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }

        XCTAssertEqual("has_priority", actual?.id)
    }

    func testExtractExperimentConfigMatchedToPropertiesFiltersbyKind() async throws {
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(id: "popup", kind: .POPUP),
                ExperimentConfig(id: "tooltip", kind: .TOOLTIP),
            ]
        )

        let popupOnly = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.POPUP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        XCTAssertEqual("popup", popupOnly?.id)

        let tooltipOnly = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.TOOLTIP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        XCTAssertEqual("tooltip", tooltipOnly?.id)

        let both = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.POPUP, .TOOLTIP]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        XCTAssertNotNil(both)

        let configOnly = await extractExperimentConfigMatchedToProperties(configs: configs, kinds: [.CONFIG]) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        XCTAssertNil(configOnly)
    }

}


final class CompareTests: XCTestCase {
    func testComparePropWithConditionValue() throws {
        let userId = "hello world"
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userId", value: userId, type: .STRING), asType: nil, value: userId, op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userRnd", value: "40", type: .INTEGER), asType: nil, value: "100", op: .LessThanOrEqual))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "version", value: "4", type: .SEMVER), asType: nil, value: "4.1", op: .LessThanOrEqual))
    }
    
    func testComparePropWithConditionValueWithPropTypeOverride() throws {
        XCTAssertFalse(comparePropWithConditionValue(
            prop: UserProperty(name: "xxx", value: "12.3", type: .STRING), asType: .STRING, value: "12", op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: UserProperty(name: "xxx", value: "12.3", type: .STRING), asType: .SEMVER, value: "12", op: .Equal))
    }

    func testCompareTimestampZWithISO8601PropAndUnixCondition() throws {
        let timestamp = 1_717_200_000
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: Date(timeIntervalSince1970: Double(timestamp)).ISO8601Format(),
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: String(timestamp),
            op: .Equal
        ))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: String(timestamp - 1),
            op: .GreaterThan
        ))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "\(timestamp - 1),\(timestamp + 1)",
            op: .Between
        ))
    }

    func testCompareTimestampZDoesNotTreatUnixMillisecondsAsSeconds() throws {
        let timestamp = 1_717_200_000
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: Date(timeIntervalSince1970: Double(timestamp)).ISO8601Format(),
            type: .TIMESTAMPZ
        )

        XCTAssertFalse(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: String(timestamp * 1000),
            op: .Equal
        ))
    }

    func testCompareTimestampZWithRFC3339Condition() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01T00:00:00Z",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T00:00:00.000Z",
            op: .Equal
        ))
    }

    func testCompareTimestampZWithColonTimezoneOffset() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01T00:00:00+00:00",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T00:00:00Z",
            op: .Equal
        ))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T00:00:00.000+00:00",
            op: .Equal
        ))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "1717200000",
            op: .Equal
        ))
    }

    func testCompareTimestampZWithNonZeroColonTimezoneOffset() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01T09:00:00+09:00",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T00:00:00Z",
            op: .Equal
        ))
    }

    func testCompareTimestampZWithLocalDateTimeString() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01T09:30:00",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T09:30:00",
            op: .Equal
        ))
    }

    func testCompareTimestampZWithLocalDateString() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01",
            op: .Equal
        ))
    }

    func testCompareTimestampZWithDateDescriptionString() throws {
        let prop = UserProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: "2024-06-01 00:00:00 +0000",
            type: .TIMESTAMPZ
        )

        XCTAssertTrue(comparePropWithConditionValue(
            prop: prop,
            asType: nil,
            value: "2024-06-01T00:00:00Z",
            op: .Equal
        ))
    }

    func testCompareTimestampZReturnsFalseWhenTimestampCannotBeParsed() throws {
        XCTAssertFalse(comparePropWithConditionValue(
            prop: UserProperty(
                name: BuiltinUserProperty.currentTime.rawValue,
                value: "invalid",
                type: .TIMESTAMPZ
            ),
            asType: nil,
            value: "invalid",
            op: .Equal
        ))
    }
    
    
    func testCompareSemverAsComparisonResultWhenOnlyMajorVersions() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "2") < 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "0") > 0, true)
    }
    
    func testCompareSemverAsComparisonResultWhenItsDifferentFormat() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1.0") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1.0") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1") == 0, true)
    }
    
    func testCompareSemverAsComparisonResult() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.2") > 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.4") < 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "2") != 0, true)
    }
    
    func testCompareSemver() throws {
        // equal
        XCTAssertTrue(compareSemver(a: "1.1", b: ["1"], op: .Equal))
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
        XCTAssertTrue(compareSemver(a: "1.0", b: ["2", "1"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["2", "3"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareSemver(a: "1.0", b: [], op: .NotIn))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["2", "3"], op: .NotIn))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1", "2"], op: .NotIn))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["2", "1"], op: .NotIn))
        
        // between
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9", "1.0.1"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1", "2"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .Between))
    }

    func testCompareSemverRejectsEmptyConditionValues() throws {
        let prop = UserProperty(name: "version", value: "1.0", type: .SEMVER)

        XCTAssertFalse(comparePropWithConditionValue(prop: prop, asType: nil, value: "1,", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: prop, asType: nil, value: "1,,2", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: prop, asType: nil, value: "", op: .Equal))
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

    func testCompareDoubleDoesNotTreatInvalidOrEmptyValuesAsZero() throws {
        let invalidProp = UserProperty(name: "invalid", value: "invalid", type: .DOUBLE)
        let zeroProp = UserProperty(name: "zero", value: "0", type: .DOUBLE)
        let oneProp = UserProperty(name: "one", value: "1", type: .DOUBLE)

        XCTAssertFalse(comparePropWithConditionValue(prop: invalidProp, asType: nil, value: "invalid", op: .Equal))
        XCTAssertFalse(comparePropWithConditionValue(prop: zeroProp, asType: nil, value: "invalid", op: .NotIn))
        XCTAssertFalse(comparePropWithConditionValue(prop: oneProp, asType: nil, value: "1,", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: oneProp, asType: nil, value: "1,,2", op: .In))
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

    func testCompareIntegerOutsideInt32Range() throws {
        let prop = UserProperty(name: "long", value: "3000000000", type: .INTEGER)

        XCTAssertTrue(comparePropWithConditionValue(prop: prop, asType: nil, value: "3000000000", op: .Equal))
        XCTAssertFalse(comparePropWithConditionValue(prop: prop, asType: nil, value: "3000000001", op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(prop: prop, asType: nil, value: "2999999999", op: .GreaterThan))
        XCTAssertTrue(comparePropWithConditionValue(prop: prop, asType: nil, value: "3000000000,3000000001", op: .Between))
    }

    func testCompareIntegerDoesNotTreatInvalidValuesAsZero() throws {
        let invalidProp = UserProperty(name: "invalid", value: "invalid", type: .INTEGER)
        let zeroProp = UserProperty(name: "zero", value: "0", type: .INTEGER)
        let oneProp = UserProperty(name: "one", value: "1", type: .INTEGER)

        XCTAssertFalse(comparePropWithConditionValue(prop: invalidProp, asType: nil, value: "invalid", op: .Equal))
        XCTAssertFalse(comparePropWithConditionValue(prop: zeroProp, asType: nil, value: "invalid", op: .NotIn))
        XCTAssertFalse(comparePropWithConditionValue(prop: oneProp, asType: nil, value: "1,", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: oneProp, asType: nil, value: "1,,2", op: .In))
    }
    
    func testCompareBoolean() throws {
        // equal
        XCTAssertTrue(compareBoolean(a: true, b: [true], op: .Equal))
        XCTAssertFalse(compareBoolean(a: true, b: [false], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareBoolean(a: false, b: [true], op: .NotEqual))
        XCTAssertFalse(compareBoolean(a: false, b: [false], op: .NotEqual))
    }

    func testCompareBooleanRejectsEmptyConditionValues() throws {
        let trueProp = UserProperty(name: "bool", value: "true", type: .BOOLEAN)
        let falseProp = UserProperty(name: "bool", value: "false", type: .BOOLEAN)

        XCTAssertFalse(comparePropWithConditionValue(prop: trueProp, asType: nil, value: "true,", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: falseProp, asType: nil, value: "true,,false", op: .In))
        XCTAssertFalse(comparePropWithConditionValue(prop: falseProp, asType: nil, value: "", op: .Equal))
    }
    
    func testParseStrToBoolean() {
        XCTAssertEqual(parseStringToBoolean("true"), true)
        XCTAssertEqual(parseStringToBoolean("True"), true)
        XCTAssertEqual(parseStringToBoolean("TRUE"), true)
        XCTAssertEqual(parseStringToBoolean("1"), true)
        
        XCTAssertEqual(parseStringToBoolean("false"), false)
        XCTAssertEqual(parseStringToBoolean("False"), false)
        XCTAssertEqual(parseStringToBoolean("FALSE"), false)
        XCTAssertEqual(parseStringToBoolean("Nil"), false)
        XCTAssertEqual(parseStringToBoolean("null"), false)
        XCTAssertEqual(parseStringToBoolean("0"), false)
    }
    
}
