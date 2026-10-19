import Foundation
import CoreFoundation

/// Canonical, immutable event property values
@_spi(ExperimentalEventProperties)
public enum EventPropertyValue: Sendable, Equatable, Codable {
    case integer(Int64)
    case float(Double)
    case string(String)
    case boolean(Bool)
    case timestamp(Date)

    private enum PropertyType: String, Codable {
        case integer
        case float
        case string
        case boolean
        case timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(PropertyType.self, forKey: .type) {
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .float: self = .float(try container.decode(Double.self, forKey: .value))
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .timestamp:
            let text = try container.decode(String.self, forKey: .value)
            guard let date = eventTimestampDate(text) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container,
                    debugDescription: "Expected a valid UTC ISO 8601 timestamp")
            }
            self = .timestamp(date)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .integer(let value):
            try container.encode(PropertyType.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case .float(let value):
            try container.encode(PropertyType.float, forKey: .type)
            try container.encode(value, forKey: .value)
        case .string(let value):
            try container.encode(PropertyType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode(PropertyType.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        case .timestamp(let value):
            guard let text = eventTimestampString(value) else {
                throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath,
                    debugDescription: "Timestamp is outside the supported date range"))
            }
            try container.encode(PropertyType.timestamp, forKey: .type)
            try container.encode(text, forKey: .value)
        }
    }
}

private func normalizedEventProperty(_ value: Any) -> EventPropertyValue? {
    if let value = value as? EventPropertyValue {
        switch value {
        case .integer, .boolean, .string: return value
        case .float(let number): return number.isFinite ? value : nil
        case .timestamp(let date): return normalizedEventProperty(date)
        }
    }
    if let value = value as? String {
        return .string(value)
    }
    if let value = value as? Date {
        guard let text = eventTimestampString(value), let date = eventTimestampDate(text) else { return nil }
        return .timestamp(date)
    }
    switch type(of: value) {
    case is Bool.Type:
        return (value as? Bool).map(EventPropertyValue.boolean)
    case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type,
         is UInt.Type, is UInt8.Type, is UInt16.Type, is UInt32.Type, is UInt64.Type:
        guard let integer = value as? any BinaryInteger else { return nil }
        return Int64(exactly: integer).map(EventPropertyValue.integer)
    case is Float.Type, is Double.Type, is CGFloat.Type:
        guard let number = value as? any BinaryFloatingPoint else { return nil }
        let double = Double(number)
        return double.isFinite ? .float(double) : nil
    default: break
    }
    guard let number = value as? NSNumber else { return nil }
    if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return .boolean(number.boolValue)
    }
    guard !(number is NSDecimalNumber) else { return nil }
    switch String(cString: number.objCType) {
    case "c", "s", "i", "l", "q": return .integer(number.int64Value)
    case "C", "S", "I", "L", "Q": return Int64(exactly: number.uint64Value).map(EventPropertyValue.integer)
    case "f", "d": return number.doubleValue.isFinite ? .float(number.doubleValue) : nil
    default: return nil
    }
}

/// Limit fractional seconds to nanoseconds, matching Android's Instant representation.
func eventTimestampString(_ date: Date) -> String? {
    let seconds = date.timeIntervalSinceReferenceDate
    guard seconds.isFinite,
          date >= Date(timeIntervalSince1970: -62_135_596_800),
          date < Date(timeIntervalSince1970: 253_402_300_800) else { return nil }
    var wholeSeconds = floor(seconds)
    let fraction = seconds - wholeSeconds
    var nanoseconds = Int((fraction * 1_000_000_000).rounded(.toNearestOrEven))
    if nanoseconds == 1_000_000_000 {
        wholeSeconds += 1
        nanoseconds = 0
    }
    let base = Date(timeIntervalSinceReferenceDate: wholeSeconds).ISO8601Format()
    guard nanoseconds != 0 else { return base }
    var fractionText = String(format: "%09ld", nanoseconds)
    while fractionText.last == "0" { fractionText.removeLast() }
    return String(base.dropLast()) + "." + fractionText + "Z"
}

private func eventTimestampDate(_ text: String) -> Date? {
    guard text.hasSuffix("Z") else { return nil }
    let parts = text.dropLast().split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard let wholeSecondsText = parts.first else { return nil }
    let hasFractionalSeconds = parts.count == 2

    if hasFractionalSeconds {
        let fractionalDigits = parts[1]
        guard !fractionalDigits.isEmpty,
              fractionalDigits.count <= 9,
              fractionalDigits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
    }

    let format = Date.ISO8601FormatStyle(includingFractionalSeconds: hasFractionalSeconds)
    guard let date = try? Date(text, strategy: format) else { return nil }

    guard date.ISO8601Format() == String(wholeSecondsText) + "Z" else { return nil }
    return eventTimestampString(date) == nil ? nil : date
}

internal func normalizeEventProperties(_ input: [String: Any]) -> [String: EventPropertyValue] {
    var values: [String: EventPropertyValue] = [:]
    var omittedProperty = false
    for (key, rawValue) in input {
        guard let property = normalizedEventProperty(rawValue) else {
            omittedProperty = true
            continue
        }
        values[key] = property
    }
    if omittedProperty {
        nubrickWarn("Omitted unsupported or lossy event properties")
    }
    return values
}
