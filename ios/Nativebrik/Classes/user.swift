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
    case FIRST_BOOT_TIME = "NATIVEBRIK_SDK_FIRST_BOOT_TIME"
    case RETENTION_PERIOD_T = "NATIVEBRIK_RETENTION_PERIOD_TIMESTMAP"
    case RETENTION_PERIOD_COUNT = "NATIVEBRIK_RETENTION_PERIOD_COUNT"
}

func nativebrikUserPropType(key: BuiltinUserProperty) -> EventPropertyType {
    switch key {
    case .userId:
        return .STRING
    case .userRnd:
        return .INTEGER
    case .currentTime:
        return .TIMESTAMPZ
    case .firstBootTime:
        return .TIMESTAMPZ
    case .lastBootTime:
        return .TIMESTAMPZ
    case .bootingTime:
        return .INTEGER
    case .retentionPeriod:
        return .INTEGER
    default:
        return .STRING
    }
}

public class NativebrikUser {
    private var properties: [String: String]
    private var lastBootTime: Double = Date.now.timeIntervalSince1970
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
        
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        self.properties[BuiltinUserProperty.languageCode.rawValue] = languageCode
        
        let regionCode = Locale.current.region?.identifier ?? "US"
        self.properties[BuiltinUserProperty.regionCode.rawValue] = regionCode

        let firstBootTime = UserDefaults.standard.object(forKey: NativebrikUserDefaultsKeys.FIRST_BOOT_TIME.rawValue) as? String ?? Date.now.ISO8601Format()
        UserDefaults.standard.set(firstBootTime, forKey: NativebrikUserDefaultsKeys.FIRST_BOOT_TIME.rawValue)
        self.properties[BuiltinUserProperty.firstBootTime.rawValue] = firstBootTime
        
        self.properties[BuiltinUserProperty.sdkVersion.rawValue] = nativebrikSdkVersion
        self.properties[BuiltinUserProperty.osName.rawValue] = UIDevice.current.systemName
        self.properties[BuiltinUserProperty.osVersion.rawValue] = UIDevice.current.systemVersion
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        self.properties[BuiltinUserProperty.appVersion.rawValue] = appVersion

        let cfBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        self.properties[BuiltinUserProperty.cfBundleVersion.rawValue] = cfBundleVersion
        
        self.comeBack()
    }
    
    public var id: String {
        get {
            return self.properties[BuiltinUserProperty.userId.rawValue] ?? ""
        }
    }
    
    public var retention: Int {
        get {
            return Int(self.properties[BuiltinUserProperty.retentionPeriod.rawValue] ?? "0") ?? 0
        }
    }

    public func set(properties: [String: String]) {
        for (key, value) in properties {
            self.properties[key] = value
        }
    }
    
    /**
     print user properties for debug
     */
    public func debugPrint() {
        let props = self.toEventProperties(seed: 0)
        var dic: [String:String] = [:]
        for prop in props {
            dic[prop.name] = prop.value
        }
        print("user", dic)
    }
    
    /**
     This function updates the internal state that indicate how many times the user came back to the app / the time user was acitivated lastly.
     This function expects to be called when your app back to foreground from background.
     */
    public func comeBack() {
        let lastBootTime = Date.now
        self.properties[BuiltinUserProperty.lastBootTime.rawValue] = lastBootTime.ISO8601Format()
        self.lastBootTime = lastBootTime.timeIntervalSince1970
        
        let retentionTimestamp = UserDefaults.standard.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue) as? Int ?? Int(Date.now.timeIntervalSince1970)
        let retentionCount = UserDefaults.standard.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue) as? Int ?? 0
        self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(retentionCount)
        
        // 1 day is equal to 86400 seconds
        let lastDaysSince1970 = Int(retentionTimestamp / (86400))
        let daysSince1970 = Int(Date.now.timeIntervalSince1970 / (86400))
        if lastDaysSince1970 == daysSince1970 - 1 {
            // count up retention. because user is returned in 1 day
            UserDefaults.standard.set(Int(Date.now.timeIntervalSince1970), forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            let countedUp = retentionCount + 1
            UserDefaults.standard.set(countedUp, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
            self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(countedUp)
        } else if lastDaysSince1970 == daysSince1970 {
            // save the initial count
            UserDefaults.standard.set(retentionTimestamp, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            UserDefaults.standard.set(retentionCount, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
        } else if lastDaysSince1970 < daysSince1970 - 1 {
            // reset retention. because user won't be returned in 1 day
            UserDefaults.standard.set(Int(Date.now.timeIntervalSince1970), forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            let reseted = 0
            UserDefaults.standard.set(reseted, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
            self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(reseted)
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
        
        eventProps.append(EventProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: Date.now.ISO8601Format(),
            type: .TIMESTAMPZ
        ))
        
        let bootingTime = Date.now.timeIntervalSince1970 - self.lastBootTime
        eventProps.append(EventProperty(
            name: BuiltinUserProperty.bootingTime.rawValue,
            value: String(Int(bootingTime)),
            type: .INTEGER
        ))
        
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
