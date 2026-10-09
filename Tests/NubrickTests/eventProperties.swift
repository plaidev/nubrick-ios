import Foundation
import XCTest
@_spi(ExperimentalEventProperties) @testable import NubrickLocal

final class EventPropertiesTests: XCTestCase {
    func testSupportedPropertiesRoundTrip() throws {
        let event = NubrickEvent("purchase", properties: [
            "amount": 19.99,
            "count": 2,
            "paid": true,
            "text": "a\"b\n/🙂",
            "date": Date(timeIntervalSince1970: 0),
        ])
        let data = try JSONEncoder().encode(event.properties)
        let decoded = try JSONDecoder().decode([String: EventValue].self, from: data)
        XCTAssertEqual(decoded["amount"], .float(19.99))
        XCTAssertEqual(decoded["count"], .integer(2))
        XCTAssertEqual(decoded["paid"], .boolean(true))
        XCTAssertEqual(decoded["date"], .timestamp(Date(timeIntervalSince1970: 0)))
        XCTAssertEqual(decoded["text"], .string("a\"b\n/🙂"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(event.properties), try encoder.encode(decoded))

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        XCTAssertEqual(json["count"]?["type"] as? String, "integer")
        XCTAssertEqual(json["amount"]?["type"] as? String, "float")
        XCTAssertEqual(json["paid"]?["type"] as? String, "boolean")
        XCTAssertEqual(json["date"]?["type"] as? String, "timestamp")
        XCTAssertEqual(json["text"]?["type"] as? String, "string")
    }

    func testInvalidValuesAreOmitted() {
        let event = NubrickEvent("e", properties: ["array": [1], "object": ["a": 1],
            "null": NSNull(), "nan": Double.nan, "inf": Float.infinity,
            "negativeInf": -Double.infinity, "decimalNaN": Decimal.nan,
            "foundationNaN": NSDecimalNumber.notANumber,
            "custom": NSObject(), "ok": false])
        XCTAssertEqual(event.properties, ["ok": .boolean(false)])
        XCTAssertTrue(NubrickEvent("e", properties: ["bad": NSNull()]).properties.isEmpty)
        XCTAssertTrue(NubrickEvent("e").properties.isEmpty)
    }

    func testSnapshotAndLegacyPayload() throws {
        var input: [String: Any] = ["n": 1, "fraction": 1.5, "flag": true, "text": "value"]
        let event = NubrickEvent("e", properties: input)
        input["n"] = 2
        var returned = event.properties
        returned["n"] = .integer(3)
        XCTAssertEqual(event.properties["n"], .integer(1))
        XCTAssertEqual(event.properties["fraction"], .float(1.5))
        XCTAssertEqual(event.properties["flag"], .boolean(true))
        XCTAssertEqual(event.properties["text"], .string("value"))
        let legacy = Data(#"{"typename":"event","name":"old","timestamp":"2026-09-29T00:00:00Z","eventUuid":"uuid"}"#.utf8)
        let old = try JSONDecoder().decode(TrackEvent.self, from: legacy)
        XCTAssertNil(old.properties)
        let stored = TrackEvent(properties: event.properties, typename: .Event,
            name: event.name, timestamp: "2026-09-29T00:00:00Z", eventUuid: "uuid")
        let reloaded = try JSONDecoder().decode(TrackEvent.self, from: JSONEncoder().encode(stored))
        XCTAssertEqual(reloaded.properties, stored.properties)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(reloaded)) as? [String: Any])
        XCTAssertNotNil(json["properties"] as? [String: Any])
    }

    func testLargePropertiesRemainInEventSnapshot() {
        let largeString = String(repeating: "x", count: 500 * 1024 + 1)
        let largeKey = String(repeating: "k", count: 4 * 1024 + 1)
        let event = NubrickEvent("e", properties: ["value": largeString, largeKey: true])
        XCTAssertEqual(event.properties, ["value": .string(largeString), largeKey: .boolean(true)])

        let properties = Dictionary(uniqueKeysWithValues: (0..<200).map {
            ("property_\($0)", String(repeating: "x", count: 32))
        })
        XCTAssertEqual(NubrickEvent("e", properties: properties).properties,
            properties.mapValues(EventValue.string))
    }

    func testFoundationPropertiesAreCopiedIntoImmutableValues() throws {
        let text = NSMutableString(string: "before")
        let number = NSNumber(value: Int64(1))
        let event = NubrickEvent("e", properties: [
            "text": text,
            "number": number,
            "integer": NSNumber(value: Int64.max),
            "fraction": NSNumber(value: 1.25),
            "flag": NSNumber(value: true),
            "date": NSDate(timeIntervalSince1970: 0),
        ])
        let encoded = try JSONEncoder().encode(event.properties)

        text.setString("after")

        XCTAssertEqual(event.properties["text"], .string("before"))
        XCTAssertEqual(event.properties["number"], .integer(1))
        XCTAssertEqual(event.properties["flag"], .boolean(true))
        XCTAssertEqual(event.properties["date"], .timestamp(Date(timeIntervalSince1970: 0)))
        let decoded = try JSONDecoder().decode([String: EventValue].self, from: encoded)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(event.properties), try encoder.encode(decoded))
        XCTAssertEqual(event.properties["integer"], .integer(Int64.max))
        XCTAssertEqual(event.properties["fraction"], .float(1.25))
    }

    func testNumericSnapshotsUseCanonicalTypes() throws {
        let integers: [Any] = [Int.min, Int8.min, Int16.min, Int32.min, Int64.min,
            UInt(Int64.max), UInt8.max, UInt16.max, UInt32.max, UInt64(Int64.max)]
        for value in integers {
            let event = NubrickEvent("e", properties: ["value": value])
            guard case .integer = event.properties["value"] else {
                return XCTFail("Expected a canonical integer for \(value)")
            }
        }
        for value in [Float(0.1) as Any, Double(Float(0.1)), CGFloat(Float(0.1))] {
            XCTAssertEqual(NubrickEvent("e", properties: ["value": value]).properties["value"], .float(Double(Float(0.1))))
        }
        for value in [Float(2) as Any, Double(2), CGFloat(2)] {
            XCTAssertEqual(NubrickEvent("e", properties: ["value": value]).properties["value"], .float(2))
        }
        let event = NubrickEvent("e", properties: ["count": Int8(3)])
        guard case .integer(let value) = event.properties["count"] else { return XCTFail("Missing count") }
        XCTAssertEqual(Int(exactly: value), 3)
    }

    func testUnsignedIntegersOutsideInt64RangeAreOmitted() {
        let event = NubrickEvent("e", properties: [
            "unsigned": UInt.max,
            "unsigned64": UInt64.max,
            "overflow": UInt64(Int64.max) + 1,
            "foundation": NSNumber(value: UInt64.max),
            "max": UInt64(Int64.max),
        ])
        XCTAssertEqual(event.properties, ["max": .integer(Int64.max)])
        XCTAssertEqual(Set(event.properties.keys), ["max"])
        XCTAssertTrue(NubrickEvent("e", properties: ["overflow": UInt64.max]).properties.isEmpty)
    }

    func testDecimalInputsAreUnsupportedEvenWhenExactlyRepresentable() throws {
        for text in ["0", "1", "1.25", "-1.25", "19.99", "0.1", "9007199254740992", "1e-128"] {
            let decimal = try XCTUnwrap(Decimal(string: text))
            let event = NubrickEvent("e", properties: [
                "native": decimal, "foundation": NSDecimalNumber(decimal: decimal), "ok": 19.99,
            ])
            XCTAssertEqual(event.properties, ["ok": .float(19.99)], text)
            XCTAssertTrue(NubrickEvent("e", properties: ["decimal": decimal]).properties.isEmpty, text)
        }
    }

    func testTypedInputsAreValidated() {
        let event = NubrickEvent("e", properties: [
            "nan": EventValue.float(.nan), "infinity": EventValue.float(.infinity),
            "date": EventValue.timestamp(Date(timeIntervalSinceReferenceDate: .infinity)),
            "valid": EventValue.integer(7),
        ])
        XCTAssertEqual(event.properties, ["valid": .integer(7)])
    }

    func testTimestampOutputPreservesNativeDatesAndFractionalSeconds() throws {
        for seconds in [0.0, -0.125, 0.125, 123_456.123456789, 800_000_000.123456789,
            Date(timeIntervalSince1970: -62_135_596_800).timeIntervalSinceReferenceDate,
            Date(timeIntervalSince1970: 253_402_300_799.125).timeIntervalSinceReferenceDate] {
            let date = Date(timeIntervalSinceReferenceDate: seconds)
            let event = NubrickEvent("e", properties: ["at": date])
            XCTAssertEqual(event.properties["at"], .timestamp(date))
            let stored = TrackEvent(properties: event.properties, typename: .Event,
                name: event.name, timestamp: "2026-09-29T00:00:00Z", eventUuid: "uuid")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let payload = try encoder.encode(stored)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            let properties = try XCTUnwrap(json["properties"] as? [String: [String: Any]])
            let timestamp = try XCTUnwrap(properties["at"]?["value"] as? String)
            XCTAssertTrue(timestamp.hasSuffix("Z"))
            XCTAssertEqual(properties["at"]?["type"] as? String, "timestamp")
            let reloaded = try JSONDecoder().decode(TrackEvent.self, from: payload)
            XCTAssertEqual(reloaded.properties?["at"], .timestamp(date))
            XCTAssertEqual(try encoder.encode(reloaded), payload)
        }
        XCTAssertTrue(NubrickEvent("e", properties: ["at": Date(timeIntervalSinceReferenceDate: Double.leastNonzeroMagnitude)]).properties.isEmpty)
    }

    func testInvalidTimestampJSONIsRejected() throws {
        for timestamp in ["", "Z", "invalid", "2026-02-30T00:00:00Z", "2026-10-09T00:00:00ZjunkZ",
            "2026-10-09T00:00:00.Z", "2026-10-09T00:00:00.1e-1Z", "2026-10-09T00:00:00.NaNZ",
            "2026-10-09T00:00:00.1e999Z"] {
            let data = try JSONSerialization.data(withJSONObject: ["type": "timestamp", "value": timestamp])
            XCTAssertThrowsError(try JSONDecoder().decode(EventValue.self, from: data), timestamp)
        }
    }

    func testNumericBoundariesSurvivePersistence() throws {
        let event = NubrickEvent("e", properties: [
            "min": Int64.min,
            "max": Int64.max,
            "unsigned": UInt64(Int64.max),
            "preciseInteger": Int64(9_007_199_254_740_993),
            "largestFloat": Double.greatestFiniteMagnitude,
            "smallestFloat": Double.leastNonzeroMagnitude,
            "tinyFloat": 1e-129,
            "wholeDouble": Double(2),
            "wholeFloat": Float(2),
            "zero": 0,
            "one": 1,
            "false": false,
            "true": true,
        ])
        let expected: [String: EventValue] = [
            "min": .integer(Int64.min),
            "max": .integer(Int64.max),
            "unsigned": .integer(Int64.max),
            "preciseInteger": .integer(9_007_199_254_740_993),
            "largestFloat": .float(Double.greatestFiniteMagnitude),
            "smallestFloat": .float(Double.leastNonzeroMagnitude),
            "tinyFloat": .float(1e-129),
            "wholeDouble": .float(2),
            "wholeFloat": .float(2),
            "zero": .integer(0),
            "one": .integer(1),
            "false": .boolean(false),
            "true": .boolean(true),
        ]
        XCTAssertEqual(event.properties, expected)
        let stored = TrackEvent(properties: event.properties, typename: .Event,
            name: event.name, timestamp: "2026-09-29T00:00:00Z", eventUuid: "uuid")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payload = try encoder.encode(stored)
        let reloaded = try JSONDecoder().decode(TrackEvent.self, from: payload)
        XCTAssertEqual(reloaded.properties, expected)
        XCTAssertEqual(try encoder.encode(reloaded), payload)
        let json = try XCTUnwrap(String(data: payload, encoding: .utf8))
        XCTAssertTrue(json.contains("9223372036854775807"))
        XCTAssertTrue(json.contains("9007199254740993"))
    }
}
