//
//  compare.swift
//  Nativebrik
//
//  Created by Takuma Jimbo on 2025/08/01.
//

import Foundation

func comparePropWithConditionValue(prop: UserProperty, asType: UserPropertyType?, value: String, op: ConditionOperator) -> Bool {
    let values = value.split(separator: ",")
    let propType = asType ?? prop.type
    switch propType {
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
            return dateFormatter.date(from: String(value))?.timeIntervalSince1970 ?? 0
        }
        return compareDouble(a: propValue, b: conditionValues, op: op)
    case .BOOLEAN:
        let propValue = parseStringToBoolean(prop.value)
        let conditionValues = values.map { value in
            return parseStringToBoolean(String(value))
        }
        return compareBoolean(a: propValue, b: conditionValues, op: op)
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

func compareBoolean(a: Bool, b: [Bool], op: ConditionOperator) -> Bool {
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


func compareSemver(a: String, b: [String], op: ConditionOperator) -> Bool {
    switch op {
    case .Equal:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == 0
    case .NotEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) != 0
    case .GreaterThan:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) > 0
    case .GreaterThanOrEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) >= 0
    case .LessThan:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) < 0
    case .LessThanOrEqual:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) <= 0
    case .In:
        return b.contains { value in
            return compareSemverAsComparisonResult(a, b[0]) == 0
        }
    case .NotIn:
        return !b.contains { value in
            return compareSemverAsComparisonResult(a, b[0]) == 0
        }
    case .Between:
        if b.count != 2 {
            return false
        }
        let left = compareSemverAsComparisonResult(a, b[0])
        let right = compareSemverAsComparisonResult(a, b[1])
        return left >= 0 && right <= 0
    default:
        if b.count == 0 {
            return false
        }
        return compareSemverAsComparisonResult(a, b[0]) == 0
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
            let nsString = input as NSString
            let count = regex.numberOfMatches(in: input, range: NSRange(location: 0, length: nsString.length))
            return count > 0
        } catch {
            return false
        }
    }
}

func parseStringToBoolean(_ str: String) -> Bool {
    let normalized = str
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))
    switch normalized {
    case "FALSE", "NO", "0", "NIL", "OFF", "NULL", "UNDEFINED", "ZERO":
        return false
    default:
        return true
    }
}

// MARK: - Constant
private let ASTERISK_IDENTIFIER: Int = -1

// MARK: - Semver
struct Semver {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String
    let build: String

    func compare(to other: SemverConstraint) -> Int {
        var majorCmp = compareComponent(major, other.major)
        if other.major == ASTERISK_IDENTIFIER {
            majorCmp = 0
        }
        var minorCmp = compareComponent(minor, other.minor)
        if other.minor == ASTERISK_IDENTIFIER {
            minorCmp = 0
        }
        var patchCmp = compareComponent(patch, other.patch)
        if other.patch == ASTERISK_IDENTIFIER {
            patchCmp = 0
        }
        var preCmp = compareComponent(prerelease, other.prerelease ?? "")
        if other.prerelease == nil {
            preCmp = 0
        }

        let ordered = [majorCmp, minorCmp, patchCmp, preCmp]
        let firstDiff = ordered.first { $0 != 0 } ?? 0
        return firstDiff < 0 ? -1 : (firstDiff == 0 ? 0 : 1)
    }

    static func decode(_ value: String) -> Semver {
        let c = SemverConstraint.decode(value)
        return Semver(
            major: c.major == ASTERISK_IDENTIFIER ? 0 : c.major,
            minor: c.minor == ASTERISK_IDENTIFIER ? 0 : c.minor,
            patch: c.patch == ASTERISK_IDENTIFIER ? 0 : c.patch,
            prerelease: c.prerelease ?? "",
            build: c.build ?? ""
        )
    }
}

// MARK: - SemverConstraint
struct SemverConstraint {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?
    let build: String?

    // 生成
    static func decode(_ value: String) -> SemverConstraint {
        guard !value.isEmpty else { return SemverConstraint() }

        // 1) build metadata（+）
        let (versionCoreAndPrerelease, buildPart) = splitOnce(value, by: "+")
        let build = buildPart.isEmpty ? nil : buildPart

        // 2) prerelease（-）
        let (versionCore, prereleasePart) = splitOnce(versionCoreAndPrerelease, by: "-")
        let prerelease = prereleasePart.isEmpty ? nil : prereleasePart

        // 3) version core（.）
        var comps = versionCore.split(separator: ".", omittingEmptySubsequences: false)
                              .map(String.init)
        while comps.count < 3 { comps.append("*") }

        let major = intOrWildcard(comps[0])
        let minor = intOrWildcard(comps[1])
        let patch = intOrWildcard(comps[2])

        return SemverConstraint(
            major: major,
            minor: minor,
            patch: patch,
            prerelease: prerelease,
            build: build
        )
    }

    init(
        major: Int = ASTERISK_IDENTIFIER,
        minor: Int = ASTERISK_IDENTIFIER,
        patch: Int = ASTERISK_IDENTIFIER,
        prerelease: String? = nil,
        build: String? = nil
    ) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

    private static func intOrWildcard(_ token: String) -> Int {
        token == "*" ? ASTERISK_IDENTIFIER : (Int(token) ?? ASTERISK_IDENTIFIER)
    }
}

func compareSemverAsComparisonResult(_ lhs: String, _ rhs: String) -> Int {
    let lhsSemver = Semver.decode(lhs)
    let rhsConstraint = SemverConstraint.decode(rhs)
    return lhsSemver.compare(to: rhsConstraint)
}

private func compareComponent<T: Comparable>(_ lhs: T, _ rhs: T) -> Int {
    lhs < rhs ? -1 : (lhs > rhs ? 1 : 0)
}

private func splitOnce(_ source: String, by separator: Character) -> (String, String) {
    if let index = source.firstIndex(of: separator) {
        let left  = String(source[..<index])
        let right = String(source[source.index(after: index)...])
        return (left, right)
    }
    return (source, "")
}
