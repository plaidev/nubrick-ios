//
//  extractionTests.swift
//  NativebrikTests
//
//  Created by Takuma Jimbo on 2025/08/01.
//

import XCTest
@testable import Nativebrik

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
    
    func testExtractExperimentConfigMatchedToPropertiesShouldReturnNilWhenItsZeroConfig() throws {
        let actual = extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: [])) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
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
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        
        XCTAssertEqual(configs.configs?[1].id, actual?.id)
    }
    
    func testExtractExperimentConfigMatchedToPropertiesWhenItsScheduled() throws {
        let now = getCurrentDate()
        let dayM1 = now.addingTimeInterval(-1000)
        let day1 = now.addingTimeInterval(1000)
        let day2 = now.addingTimeInterval(2000)
        
        let configs = ExperimentConfigs(
            configs: [
                ExperimentConfig(
                    id: "id_0",
                    startedAt: formatToISO8601(day1)
                ),
                ExperimentConfig(
                    id: "id_1",
                    endedAt: formatToISO8601(dayM1)
                ),
                ExperimentConfig(
                    id: "now",
                    startedAt: formatToISO8601(dayM1),
                    endedAt: formatToISO8601(day2)
                ),
            ]
        )
        
        let actual = extractExperimentConfigMatchedToProperties(configs: ExperimentConfigs(configs: configs.configs)) { seed in
            return []
        } isNotInFrequency: { experimentId, frequency in
            return true
        } isMatchedToUserEventFrequencyConditions: { conditions in
            return true
        }
        
        XCTAssertEqual("now", actual?.id)
    }

}
