import Foundation
import CoreFoundation

/// Canonical, immutable event property values
@_spi(ExperimentalEventProperties)
public enum EventValue: Sendable, Equatable, Codable {
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
                    debugDescription: "Timestamp cannot be encoded without losing information"))
            }
            try container.encode(PropertyType.timestamp, forKey: .type)
            try container.encode(text, forKey: .value)
        }
    }
}

private func normalizedEventProperty(_ value: Any) -> EventValue? {
    if let value = value as? EventValue {
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
        guard eventTimestampString(value) != nil else { return nil }
        return .timestamp(value)
    }
    switch type(of: value) {
    case is Bool.Type:
        return (value as? Bool).map(EventValue.boolean)
    case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type,
         is UInt.Type, is UInt8.Type, is UInt16.Type, is UInt32.Type, is UInt64.Type:
        guard let integer = value as? any BinaryInteger else { return nil }
        return Int64(exactly: integer).map(EventValue.integer)
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
    case "C", "S", "I", "L", "Q": return Int64(exactly: number.uint64Value).map(EventValue.integer)
    case "f", "d": return number.doubleValue.isFinite ? .float(number.doubleValue) : nil
    default: return nil
    }
}

/// Keep fractional seconds and verify that formatting preserves the original Date value.
private func eventTimestampString(_ date: Date) -> String? {
    let seconds = date.timeIntervalSinceReferenceDate
    guard seconds.isFinite,
          date >= Date(timeIntervalSince1970: -62_135_596_800),
          date < Date(timeIntervalSince1970: 253_402_300_800) else { return nil }
    let wholeSeconds = floor(seconds)
    let fraction = seconds - wholeSeconds
    let base = Date(timeIntervalSinceReferenceDate: wholeSeconds).ISO8601Format()
    guard fraction != 0 else { return base }
    var fractionText = String(format: "%.17f", locale: Locale(identifier: "en_US_POSIX"), fraction)
    while fractionText.last == "0" { fractionText.removeLast() }
    guard let recoveredFraction = Double(fractionText),
          Date(timeIntervalSinceReferenceDate: wholeSeconds + recoveredFraction) == date else { return nil }
    return String(base.dropLast()) + String(fractionText.dropFirst()) + "Z"
}

// Parse whole seconds and the fraction separately to retain Date's original precision.
private func eventTimestampDate(_ text: String) -> Date? {
    guard text.hasSuffix("Z") else { return nil }
    let parts = text.dropLast().split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard let wholeSeconds = parts.first,
          let base = ISO8601DateFormatter().date(from: String(wholeSeconds) + "Z"),
          base.ISO8601Format() == String(wholeSeconds) + "Z",
          parts.count == 1 || (!parts[1].isEmpty && parts[1].allSatisfy { $0.isASCII && $0.isNumber }),
          let fraction = parts.count == 2 ? Double("0." + parts[1]) : 0,
          fraction.isFinite, (0..<1).contains(fraction) else { return nil }
    let date = Date(timeIntervalSinceReferenceDate: base.timeIntervalSinceReferenceDate + fraction)
    return eventTimestampString(date) == nil ? nil : date
}

internal func normalizeEventProperties(_ input: [String: Any]) -> [String: EventValue] {
    var values: [String: EventValue] = [:]
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
