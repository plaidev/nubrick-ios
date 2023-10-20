//
//  user.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation
import UIKit

typealias ExperimentHistoryRecord = TimeInterval

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
    case .osVersion:
        return .SEMVER
    case .sdkVersion:
        return .SEMVER
    case .appVersion:
        return .SEMVER
    case .cfBundleVersion:
        return .SEMVER
    default:
        return .STRING
    }
}

public class NativebrikUser {
    private var properties: [String: String]
    private var lastBootTime: Double = getCurrentDate().timeIntervalSince1970
    private var userDB: UserDefaults
    
    init() {
        let suiteName = "\(Bundle.main.bundleIdentifier ?? "app").nativebrik.com"
        self.userDB = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        self.properties = [:]
        
        // userId := uuid by default
        let userId = self.userDB.object(forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue) as? String ?? UUID().uuidString
        self.userDB.set(userId, forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue)
        self.properties[BuiltinUserProperty.userId.rawValue] = userId
        
        // userRnd := n in [0,100)
        let userRnd = self.userDB.object(forKey: NativebrikUserDefaultsKeys.USER_RND.rawValue) as? Int ?? Int.random(in: 0..<100)
        self.userDB.set(userRnd, forKey: NativebrikUserDefaultsKeys.USER_RND.rawValue)
        self.properties[BuiltinUserProperty.userRnd.rawValue] = String(userRnd)
        
        let languageCode = getLanguageCode()
        self.properties[BuiltinUserProperty.languageCode.rawValue] = languageCode
        
        let regionCode = getRegionCode()
        self.properties[BuiltinUserProperty.regionCode.rawValue] = regionCode

        let firstBootTime = self.userDB.object(forKey: NativebrikUserDefaultsKeys.FIRST_BOOT_TIME.rawValue) as? String ?? formatToISO8601(getCurrentDate())
        self.userDB.set(firstBootTime, forKey: NativebrikUserDefaultsKeys.FIRST_BOOT_TIME.rawValue)
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

    public func set(_ properties: [String: String]) {
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
        let now = getCurrentDate()
        let lastBootTime = getCurrentDate()
        self.properties[BuiltinUserProperty.lastBootTime.rawValue] = formatToISO8601(lastBootTime)
        self.lastBootTime = lastBootTime.timeIntervalSince1970
        
        let retentionTimestamp = self.userDB.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue) as? Int ?? Int(now.timeIntervalSince1970)
        let retentionCount = self.userDB.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue) as? Int ?? 0
        self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(retentionCount)
        
        // 1 day is equal to 86400 seconds
        let lastDaysSince1970 = Int(retentionTimestamp / (86400))
        let daysSince1970 = Int(now.timeIntervalSince1970 / (86400))
        if lastDaysSince1970 == daysSince1970 - 1 {
            // count up retention. because user is returned in 1 day
            self.userDB.set(Int(now.timeIntervalSince1970), forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            let countedUp = retentionCount + 1
            self.userDB.set(countedUp, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
            self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(countedUp)
        } else if lastDaysSince1970 == daysSince1970 {
            // save the initial count
            self.userDB.set(retentionTimestamp, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            self.userDB.set(retentionCount, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
        } else if lastDaysSince1970 < daysSince1970 - 1 {
            // reset retention. because user won't be returned in 1 day
            self.userDB.set(Int(now.timeIntervalSince1970), forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
            let reseted = 0
            self.userDB.set(reseted, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)
            self.properties[BuiltinUserProperty.retentionPeriod.rawValue] = String(reseted)
        }
    }
    
    func getExperimentHistoryRecord(experimentId: String) -> [ExperimentHistoryRecord] {
        let key = "NATIVEBRIK_EXPERIMENTET_RECORDS_\(experimentId)"
        let records = self.userDB.object(forKey: key) as? [ExperimentHistoryRecord]
        return records ?? []
    }
    
    func addExperimentHistoryRecord(experimentId: String) {
        var records = self.getExperimentHistoryRecord(experimentId: experimentId)
        let key = "NATIVEBRIK_EXPERIMENTET_RECORDS_\(experimentId)"
        records.insert(ExperimentHistoryRecord(getCurrentDate().timeIntervalSince1970), at: 0)
        if records.count > 365 {
            records.removeLast()
        }
        self.userDB.set(records, forKey: key)
    }
    
    // returns [0, 100)
    func getSeededUserRnd(seed: Int) -> Int {
        let rndStr = self.properties[BuiltinUserProperty.userRnd.rawValue] ?? "0"
        let rnd = Int(rndStr) ?? 0
        srand48(seed)
        let seededRand = drand48() * 100.0
        return (rnd + Int(seededRand)) % 100
    }
    
    // returns [0, 1)
    func getSeededNormalizedUserRnd(seed: Int) -> Double {
        let seededRnd = getSeededUserRnd(seed: seed)
        return Double(seededRnd) / 100.0
    }
    
    func toEventProperties(seed: Int) -> [EventProperty] {
        let now = getCurrentDate()
        var eventProps: [EventProperty] = []
        
        // set properties that depend on current time.
        eventProps.append(EventProperty(
            name: BuiltinUserProperty.currentTime.rawValue,
            value: formatToISO8601(now),
            type: .TIMESTAMPZ
        ))
        
        let bootingTime = now.timeIntervalSince1970 - self.lastBootTime
        eventProps.append(EventProperty(
            name: BuiltinUserProperty.bootingTime.rawValue,
            value: String(Int(bootingTime)),
            type: .INTEGER
        ))
        
        let localDates = getLocalDateComponent(now)
        eventProps.append(contentsOf: [
            EventProperty(
                name: BuiltinUserProperty.localYear.rawValue,
                value: String(localDates.year),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localMonth.rawValue,
                value: String(localDates.month),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localDay.rawValue,
                value: String(localDates.day),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localHour.rawValue,
                value: String(localDates.hour),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localMinute.rawValue,
                value: String(localDates.minute),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localSecond.rawValue,
                value: String(localDates.second),
                type: .INTEGER
            ),
            EventProperty(
                name: BuiltinUserProperty.localWeekday.rawValue,
                value: localDates.weekday.rawValue,
                type: .INTEGER
            ),
        ])
        
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
