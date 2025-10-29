//
//  remote-config.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import UIKit
import MetricKit
import Darwin.Mach

private let CRASH_RECORD_KEY: String = "NATIVEBRIK_CRASH_RECORD"

// convert MetricKit exception type to string
func exceptionTypeString(_ num: NSNumber?) -> String {
    guard let raw = num?.uint32Value else { return "UNKNOWN(nil)" }
    let t = exception_type_t(raw)
    switch t {
    case EXC_BAD_ACCESS:     return "EXC_BAD_ACCESS"
    case EXC_BAD_INSTRUCTION:return "EXC_BAD_INSTRUCTION"
    case EXC_ARITHMETIC:     return "EXC_ARITHMETIC"
    case EXC_EMULATION:      return "EXC_EMULATION"
    case EXC_SOFTWARE:       return "EXC_SOFTWARE"
    case EXC_BREAKPOINT:     return "EXC_BREAKPOINT"
    case EXC_SYSCALL:        return "EXC_SYSCALL"
    case EXC_MACH_SYSCALL:   return "EXC_MACH_SYSCALL"
    case EXC_RPC_ALERT:      return "EXC_RPC_ALERT"
    case EXC_CRASH:          return "EXC_CRASH"
    case EXC_RESOURCE:       return "EXC_RESOURCE"
    case EXC_GUARD:          return "EXC_GUARD"
    case EXC_CORPSE_NOTIFY:  return "EXC_CORPSE_NOTIFY"
    default:                 return "UNKNOWN(\(raw))"
    }
}
 
//internal classes that map structure of CallStack inside MetricKit object
private struct CallStackTree: Decodable {
    let callStacks: [CallStack]?
    let callStackPerThread: Bool?
}

private struct CallStack: Decodable {
    let threadAttributed: Bool?
    let callStackRootFrames: [RawFrame]?
}

private struct RawFrame: Decodable {
    let address: UInt64?
    let binaryName: String?
    let binaryUUID: String?
    let offsetIntoBinaryTextSegment: UInt64?
    let sampleCount: Int?
    let subFrames: [RawFrame]?
}

struct ExceptionRecord: Encodable {
    let type: String?
    let message: String?
    let callStacks: [Frame]?
}

struct Frame: Encodable {
    let imageAddr: String?
    let instructionAddr: String?
    let binaryUUID: String?
    let binaryName: String?
}

protocol TrackRepository2 {
    func trackExperimentEvent(_ event: TrackExperimentEvent)
    func trackEvent(_ event: TrackUserEvent)
    
    @available(iOS 14.0, *)
    func report(_ crash: MXCrashDiagnostic)
}

struct TrackRequest: Encodable {
    var projectId: String
    var userId: String
    var timestamp: DateTime
    var events: [TrackEvent]
    var meta: TrackEventMeta
}

struct TrackEvent: Encodable {
    enum Typename: String, Encodable {
        case Event = "event"
        case Experiment = "experiment"
        case Crash = "crash"
    }
    var typename: Typename
    var experimentId: String?
    var variantId: String?
    var name: String?
    var timestamp: DateTime
    var exceptions: [ExceptionRecord]?
}

struct TrackEventMeta: Encodable {
    var appId: String?
    var appVersion: String?
    var cfBundleVersion: String?
    var osName: String?
    var osVersion: String?
    var sdkVersion: String?
    var platform: String? = "ios"
}

struct TrackUserEvent {
    var name: String
}

struct TrackExperimentEvent {
    var experimentId: String
    var variantId: String
}

struct TrackCrashEvent {
    var type: String
    var message: String
    var exceptions: [ExceptionRecord]
}

// Convert UInt64 to hex string
private func hex(_ v: UInt64) -> String {
    String(format: "0x%016llx", v)
}

/// Compute image_addr (load address) from a MetricKit frame.
/// Sentry wants `image_addr` in hex.
func imageAddrHex(addressDec: UInt64, offsetIntoTextDec: UInt64) -> String? {
    guard addressDec >= offsetIntoTextDec else { return nil } // invalid
    let load = addressDec - offsetIntoTextDec
    return hex(load)
}


class TrackRespositoryImpl: TrackRepository2 {
    private let maxQueueSize: Int
    private let maxBatchSize: Int
    private let config: Config
    private let user: NubrickUser
    private let queueLock: NSLock
    private var timer: Timer?
    private var buffer: [TrackEvent]
    init(config: Config, user: NubrickUser) {
        self.maxQueueSize = 300
        self.maxBatchSize = 50
        self.config = config
        self.user = user
        self.queueLock = NSLock()
        self.buffer = []
        self.timer = nil
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func trackExperimentEvent(_ event: TrackExperimentEvent) {
        self.pushToQueue(TrackEvent(
            typename: .Experiment,
            experimentId: event.experimentId,
            variantId: event.variantId,
            timestamp: formatToISO8601(getCurrentDate())
        ))
    }
    
    func trackEvent(_ event: TrackUserEvent) {
        self.pushToQueue(TrackEvent(
            typename: .Event,
            name: event.name,
            timestamp: formatToISO8601(getCurrentDate())
        ))
    }
    
    private func pushToQueue(_ event: TrackEvent) {
        self.queueLock.lock()
        if self.timer == nil {
            // here, use async not sync. main.sync will break the app.
            DispatchQueue.main.async {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true, block: { _ in
                    Task(priority: .low) {
                        try await self.sendAndFlush()
                    }
                })
            }
        }
        
        if self.buffer.count >= self.maxBatchSize {
            Task(priority: .low) {
                try await self.sendAndFlush()
            }
        }
        self.buffer.append(event)
        if self.buffer.count >= self.maxQueueSize {
            self.buffer.removeFirst(self.maxQueueSize - self.buffer.count)
        }
        
        self.queueLock.unlock()
    }
    
    private func sendAndFlush() async throws {
        if self.buffer.count == 0 {
            return
        }
        let events = self.buffer
        self.buffer = []
        
        let appId = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let cfBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let trackMeta = await TrackEventMeta(
            appId: appId,
            appVersion: appVersion,
            cfBundleVersion: cfBundleVersion,
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            sdkVersion: nubrickSdkVersion
        )
        let trackRequest = TrackRequest(
            projectId: self.config.projectId,
            userId: self.user.id,
            timestamp: formatToISO8601(getCurrentDate()),
            events: events,
            meta: trackMeta
        )
        
        do {
            let url = URL(string: config.trackUrl)!
            let jsonData = try JSONEncoder().encode(trackRequest)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let _ = try await nativebrikSession.data(for: request)
            
            self.timer?.invalidate()
            self.timer = nil
        } catch {
            self.buffer.append(contentsOf: events)
        }
    }
    
    @available(iOS 14.0, *)
    func report(_ crash: MXCrashDiagnostic) {
        if let callStackTree = try? JSONDecoder().decode(
            CallStackTree.self,
            from: crash.callStackTree.jsonRepresentation()
        )
        {
            var frames = [Frame]()

            // Process all call stacks, not just threadAttributed ones
            if let allCallStacks = callStackTree.callStacks {
                for currentCallStack in allCallStacks {
                    var rawFramesToProcess = currentCallStack.callStackRootFrames ?? []

                    while !rawFramesToProcess.isEmpty {
                        let rawFrame = rawFramesToProcess.removeFirst()
                        // if rawFrame.binaryName?.contains("Nubrick") ?? false {
                        frames.append(Frame(
                            imageAddr: hex(rawFrame.offsetIntoBinaryTextSegment ?? 0),
                            instructionAddr: hex(rawFrame.address ?? 0),
                            binaryUUID: rawFrame.binaryUUID,
                            binaryName: rawFrame.binaryName
                        ))
                        // }

                        if let subFrames = rawFrame.subFrames {
                            rawFramesToProcess.insert(contentsOf: subFrames, at: 0)
                        }
                    }
                }
            }
            
            let exceptionRecord = ExceptionRecord(
                type: exceptionTypeString(crash.exceptionType),
                message: crash.terminationReason,
                callStacks: frames
            )
            let causedByNativebrik = !(exceptionRecord.callStacks?.isEmpty ?? true)
            self.buffer.append(TrackEvent(
                typename: .Event,
                name: TriggerEventNameDefs.N_ERROR_RECORD.rawValue,
                timestamp: formatToISO8601(getCurrentDate())
            ))
            if causedByNativebrik {
                self.buffer.append(TrackEvent(
                    typename: .Event,
                    name: TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD.rawValue,
                    timestamp: formatToISO8601(getCurrentDate())
                ))
                self.buffer.append(TrackEvent(
                    typename: .Crash,
                    timestamp: formatToISO8601(getCurrentDate()),
                    exceptions: [exceptionRecord]
                ))
            }
        
            Task.detached(priority: .utility) {
                try await self.sendAndFlush()
            }
        }
    }
}
