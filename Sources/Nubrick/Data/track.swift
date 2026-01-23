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

@_spi(FlutterBridge)
public struct StackFrame: Encodable {
    // iOS fields
    public let imageAddr: String?
    public let instructionAddr: String?
    public let binaryUUID: String?
    public let binaryName: String?

    // Android/Flutter fields
    public let fileName: String?
    public let className: String?
    public let methodName: String?
    public let lineNumber: Int?

    public init(
        imageAddr: String? = nil,
        instructionAddr: String? = nil,
        binaryUUID: String? = nil,
        binaryName: String? = nil,
        fileName: String? = nil,
        className: String? = nil,
        methodName: String? = nil,
        lineNumber: Int? = nil
    ) {
        self.imageAddr = imageAddr
        self.instructionAddr = instructionAddr
        self.binaryUUID = binaryUUID
        self.binaryName = binaryName
        self.fileName = fileName
        self.className = className
        self.methodName = methodName
        self.lineNumber = lineNumber
    }
}

@_spi(FlutterBridge)
public struct ExceptionRecord: Encodable {
    public let type: String?
    public let message: String?
    public let callStacks: [StackFrame]?

    public init(
        type: String? = nil,
        message: String? = nil,
        callStacks: [StackFrame]? = nil
    ) {
        self.type = type
        self.message = message
        self.callStacks = callStacks
    }
}

@_spi(FlutterBridge)
public struct TrackCrashEvent {
    public let exceptions: [ExceptionRecord]
    public let threads: [ThreadRecord]?
    public let platform: String?
    public let flutterSdkVersion: String?
    public let severity: CrashSeverity

    public init(
        exceptions: [ExceptionRecord],
        threads: [ThreadRecord]? = nil,
        platform: String? = nil,
        flutterSdkVersion: String? = nil,
        severity: CrashSeverity = .error
    ) {
        self.exceptions = exceptions
        self.threads = threads
        self.platform = platform
        self.flutterSdkVersion = flutterSdkVersion
        self.severity = severity
    }
}

/// Severity level for crash/error reporting.
@_spi(FlutterBridge)
public enum CrashSeverity: String {
    case debug, info, warning, error, fatal

    /// Returns true if this severity level should be counted as an error (error or fatal).
    public var isErrorLevel: Bool {
        self == .error || self == .fatal
    }

    /// Parses a string into a CrashSeverity, defaulting to .error for nil, empty, or invalid values.
    public static func from(_ string: String?) -> CrashSeverity {
        guard let string = string, !string.isEmpty else { return .error }
        return CrashSeverity(rawValue: string) ?? .error
    }
}

protocol TrackRepository2 {
    func trackExperimentEvent(_ event: TrackExperimentEvent)
    func trackEvent(_ event: TrackUserEvent)

    @available(iOS 14.0, *)
    func processMetricKitCrash(_ crash: MXCrashDiagnostic)

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent)
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
    var threads: [ThreadRecord]?
    var platform: String?
    var flutterSdkVersion: String?
    var severity: String?
}

@_spi(FlutterBridge)
public struct ThreadRecord: Encodable {
    public let isMain: Bool?
    public let stacktrace: [StackFrame]?
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
        self.queueLock.withLock {
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
            if self.buffer.count > self.maxQueueSize {
                let overflow = self.buffer.count - self.maxQueueSize
                self.buffer.removeFirst(overflow)
            }
        }
    }
    
    private func sendAndFlush() async throws {
        // Acquire lock to safely read and clear buffer
        let events: [TrackEvent] = self.queueLock.withLock {
            guard self.buffer.count > 0 else {
                return []
            }

            let events = self.buffer
            self.buffer = []
            return events
        }

        guard events.count > 0 else { return }

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

            // Acquire lock before modifying timer
            self.queueLock.withLock {
                self.timer?.invalidate()
                self.timer = nil
            }
        } catch {
            // Acquire lock before restoring buffer
            self.queueLock.withLock {
                self.buffer.append(contentsOf: events)
            }
        }
    }
    
    @available(iOS 14.0, *)
    func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
        if let callStackTree = try? JSONDecoder().decode(
            CallStackTree.self,
            from: crash.callStackTree.jsonRepresentation()
        )
        {
            var mainThreadFrames = [StackFrame]()
            var threads = [ThreadRecord]()

            // Process all call stacks (limit to prevent malformed data issues)
            if let allCallStacks = callStackTree.callStacks {
                let maxFramesPerThread = 1000

                for currentCallStack in allCallStacks {
                    var threadFrames = [StackFrame]()
                    var rawFramesToProcess = currentCallStack.callStackRootFrames ?? []

                    while !rawFramesToProcess.isEmpty && threadFrames.count < maxFramesPerThread {
                        let rawFrame = rawFramesToProcess.removeFirst()
                        let address = rawFrame.address ?? 0
                        let offset = rawFrame.offsetIntoBinaryTextSegment ?? 0
                        let frame = StackFrame(
                            imageAddr: imageAddrHex(addressDec: address, offsetIntoTextDec: offset) ?? hex(offset),
                            instructionAddr: hex(address),
                            binaryUUID: rawFrame.binaryUUID,
                            binaryName: rawFrame.binaryName
                        )
                        threadFrames.append(frame)

                        if let subFrames = rawFrame.subFrames {
                            rawFramesToProcess.insert(contentsOf: subFrames, at: 0)
                        }
                    }

                    // Create a ThreadRecord for each call stack
                    let isMainThread = currentCallStack.threadAttributed ?? false
                    threads.append(ThreadRecord(
                        isMain: isMainThread,
                        stacktrace: threadFrames
                    ))

                    // Keep main thread frames for exception record
                    if isMainThread {
                        mainThreadFrames = threadFrames
                    }
                }
            }

            let exceptionRecord = ExceptionRecord(
                type: exceptionTypeString(crash.exceptionType),
                message: crash.terminationReason,
                callStacks: mainThreadFrames
            )

            let crashEvent = TrackCrashEvent(
                exceptions: [exceptionRecord],
                threads: threads,
                platform: "ios"
            )
            sendCrashToBackend(crashEvent)
        }
    }

    private func sendCrashToBackend(_ crashEvent: TrackCrashEvent) {
        // Check if crash is caused by Nubrick
        let causedByNativebrik: Bool
        if let threads = crashEvent.threads {
            causedByNativebrik = threads.contains { thread in
                thread.stacktrace?.contains { frame in
                    frame.binaryName?.contains("Nubrick") ?? false ||
                    frame.className?.contains("package:nativebrik_bridge") ?? false ||
                    frame.className?.contains("io.nubrick.nubrick") ?? false
                } ?? false
            }
        } else {
            causedByNativebrik = crashEvent.exceptions.contains { exception in
                exception.callStacks?.contains { frame in
                    frame.binaryName?.contains("Nubrick") ?? false ||
                    frame.className?.contains("package:nativebrik_bridge") ?? false ||
                    frame.className?.contains("io.nubrick.nubrick") ?? false
                } ?? false
            }
        }

        // Acquire lock before modifying buffer
        self.queueLock.withLock {
            // Only send error tracking events for error or fatal severity
            if crashEvent.severity.isErrorLevel {
                self.buffer.append(TrackEvent(
                    typename: .Event,
                    name: TriggerEventNameDefs.N_ERROR_RECORD.rawValue,
                    timestamp: formatToISO8601(getCurrentDate()),
                    platform: nil
                ))
            }
            if causedByNativebrik {
                if crashEvent.severity.isErrorLevel {
                    self.buffer.append(TrackEvent(
                        typename: .Event,
                        name: TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD.rawValue,
                        timestamp: formatToISO8601(getCurrentDate()),
                        platform: nil
                    ))
                }
                self.buffer.append(TrackEvent(
                    typename: .Crash,
                    timestamp: formatToISO8601(getCurrentDate()),
                    exceptions: crashEvent.exceptions,
                    threads: crashEvent.threads,
                    platform: crashEvent.platform,
                    flutterSdkVersion: crashEvent.flutterSdkVersion,
                    severity: crashEvent.severity.rawValue
                ))
            }
        }

        Task.detached(priority: .utility) {
            try await self.sendAndFlush()
        }
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        sendCrashToBackend(crashEvent)
    }
}
