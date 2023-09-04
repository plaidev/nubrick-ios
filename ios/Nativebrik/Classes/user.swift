//
//  user.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation

enum NativebrikUserDefaultsKeys: String {
    case USER_ID = "NATIVEBRIK_SDK_USER_ID"
    case USER_RND = "NATIVEBRIK_SDK_USER_RND"
}

func nativebrikUserPropType(key: BuiltinUserProperty) -> EventPropertyType {
    switch key {
    case .userId:
        return .STRING
    case .userRnd:
        return .INTEGER
    default:
        return .STRING
    }
}

public class NativebrikUser {
    private var properties: [String: String]
    init() {
        self.properties = [:]
        
        // userId := uuid by default
        let userId = UserDefaults.standard.object(forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue) as? String ?? UUID().uuidString
        UserDefaults.standard.set(userId, forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue)
        self.properties[BuiltinUserProperty.userId.rawValue] = userId
        
        // userRnd := n in [0,100)
        let userRnd = UserDefaults.standard.object(forKey: NativebrikUserDefaultsKeys.USER_RND.rawValue) as? Int ?? Int.random(in: 0..<100)
        UserDefaults.standard.set(userRnd, forKey: NativebrikUserDefaultsKeys.USER_RND.rawValue)
        self.properties[BuiltinUserProperty.userRnd.rawValue] = String(userRnd)
    }
    
    public var id: String {
        get {
            return self.properties[BuiltinUserProperty.userId.rawValue] ?? ""
        }
    }

    public func set(properties: [String: String]) {
        for (key, value) in properties {
            self.properties[key] = value
        }
    }
    
    // returns [0, 100)
    func getSeededUserRnd(seed: Int) -> Int {
        let rndStr = self.properties[BuiltinUserProperty.userRnd.rawValue] ?? "0"
        let rnd = Int(rndStr) ?? 0
        srand48(seed)
        let seededRand = drand48() * 100.0
        return (rnd + Int(seededRand)) % 100
    }
    
    func getSeededNormalizedUserRnd(seed: Int) -> Double {
        let seededRnd = getSeededUserRnd(seed: seed)
        return Double(seededRnd) / 100.0
    }
    
    func toEventProperties(seed: Int) -> [EventProperty] {
        var eventProps: [EventProperty] = []
        for (key, value) in self.properties {
            if key == BuiltinUserProperty.userRnd.rawValue {
                let eventProp = EventProperty(
                    name: key,
                    value: String(getSeededUserRnd(seed: seed)),
                    type: nativebrikUserPropType(key: BuiltinUserProperty(rawValue: key) ?? .unknown)
                )
                eventProps.append(eventProp)
            } else {
                let eventProp = EventProperty(name: key, value: value, type: nativebrikUserPropType(key: BuiltinUserProperty(rawValue: key) ?? .unknown))
                eventProps.append(eventProp)
            }
        }
        return eventProps
    }
}
