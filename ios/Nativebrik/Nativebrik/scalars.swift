//
//  scalars.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation

typealias DateTime = String
typealias Boolean = Bool
typealias UIBlockJSON = UIBlock

struct JSON: Decodable {
  var value: Any?

  private struct CodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }
    init?(stringValue: String) { self.stringValue = stringValue }
  }

  public init(value: Any) {
    self.value = value
  }

  public init(from decoder: Decoder) throws {
    if let container = try? decoder.container(keyedBy: CodingKeys.self) {
      var result = [String: Any]()
      try container.allKeys.forEach { (key) throws in
        result[key.stringValue] = try container.decode(JSON.self, forKey: key).value
      }
      value = result
    } else if var container = try? decoder.unkeyedContainer() {
      var result = [Any]()
      while !container.isAtEnd {
          if let value = try container.decode(JSON.self).value {
              result.append(value)
          }
      }
      value = result
    } else if let container = try? decoder.singleValueContainer() {
      if let intVal = try? container.decode(Int.self) {
        value = intVal
      } else if let doubleVal = try? container.decode(Double.self) {
        value = doubleVal
      } else if let boolVal = try? container.decode(Bool.self) {
        value = boolVal
      } else if let stringVal = try? container.decode(String.self) {
        value = stringVal
      } else {
        value = nil
      }
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Could not serialise"))
    }
  }
}

extension JSON: Encodable {
  public func encode(to encoder: Encoder) throws {
    if let array = value as? [Any] {
      var container = encoder.unkeyedContainer()
      for value in array {
        let decodable = JSON(value: value)
        try container.encode(decodable)
      }
    } else if let dictionary = value as? [String: Any] {
      var container = encoder.container(keyedBy: CodingKeys.self)
      for (key, value) in dictionary {
        let codingKey = CodingKeys(stringValue: key)!
        let decodable = JSON(value: value)
        try container.encode(decodable, forKey: codingKey)
      }
    } else {
      var container = encoder.singleValueContainer()
      if let intVal = value as? Int {
        try container.encode(intVal)
      } else if let doubleVal = value as? Double {
        try container.encode(doubleVal)
      } else if let boolVal = value as? Bool {
        try container.encode(boolVal)
      } else if let stringVal = value as? String {
        try container.encode(stringVal)
      } else {
          try container.encodeNil()
      }
    }
  }
}

extension UIBlock: Hashable {
  private var rawValue: String {
    let value: String
    switch self {
    case .EUIRootBlock(let block):
        value = block.id ?? ""
    case .EUIPageBlock(let block):
        value = block.id ?? ""
    case .EUIFlexContainerBlock(let block):
      value = block.id ?? ""
    case .EUICollectionBlock(let block):
        value = block.id ?? ""
    case .EUICarouselBlock(let block):
        value = block.id ?? ""
    case .EUIImageBlock(let block):
      value = block.id ?? ""
    case .EUITextBlock(let block):
      value = block.id ?? ""
    case .EUITextInputBlock(let block):
        value = block.id ?? ""
    case .EUISelectInputBlock(let block):
        value = block.id ?? ""
    case .unknown:
      value = "unknown"
    }
    return value
  }

  public static func == (lhs: UIBlock, rhs: UIBlock) -> Bool {
    return lhs.rawValue == rhs.rawValue
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }
}
