//
//  remote-config.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import UIKit
import Darwin.Mach
import CoreData

private let CRASH_RECORD_KEY: String = "NATIVEBRIK_CRASH_RECORD"

private func trackWarn(_ message: String) {
    print("[Nubrick] \(message)")
}

// Convert MetricKit exception type to string after copying the raw value out of the diagnostic.
func exceptionTypeString(_ raw: UInt32?) -> String {
    guard let raw else { return "UNKNOWN(nil)" }
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
public struct StackFrame: Codable, Sendable {
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
public struct ExceptionRecord: Codable, Sendable {
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
public struct TrackCrashEvent: Sendable {
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
public enum CrashSeverity: String, Sendable {
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

protocol TrackRepository2 : Actor {
    func trackExperimentEvent(_ event: TrackExperimentEvent) async
    func trackEvent(_ event: TrackUserEvent) async
    func flushNow() async

    func processMetricKitCrash(
        callStackTreeJSON: Data,
        terminationReason: String?,
        exceptionType: UInt32?
    ) async

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) async
    func sendSurveyResponse(experimentId: String, variantId: String, response_data: String) async
}

struct SurveyResponseRequest: Encodable {
    var timestamp: DateTime
    var projectId: String
    var experimentId: String
    var variantId: String
    var userId: String
    var response_data: String
    var meta: TrackEventMeta
}

struct TrackRequest: Encodable {
    var projectId: String
    var userId: String
    var timestamp: DateTime
    var events: [TrackEvent]
    var meta: TrackEventMeta
}

struct TrackEvent: Codable {
    enum Typename: String, Codable {
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
    var eventUuid: String
}

@_spi(FlutterBridge)
public struct ThreadRecord: Codable, Sendable {
    /// For MetricKit crashes, this is the crash-attributed thread. The JSON
    /// field name is retained for backend compatibility.
    public let isMain: Bool?
    public let stacktrace: [StackFrame]?
}

func isNubrickFrame(_ frame: StackFrame) -> Bool {
    frame.binaryName?.contains("Nubrick") ?? false ||
        frame.className?.contains("package:nubrick_flutter") ?? false ||
        frame.className?.contains("app.nubrick.flutter.nubrick_flutter") ?? false ||
        frame.className?.contains("io.nubrick.nubrick") ?? false
}

func isNubrickCausedCrash(_ crashEvent: TrackCrashEvent) -> Bool {
    if let threads = crashEvent.threads {
        // MetricKit captures stacks from multiple threads. A Nubrick frame on
        // an unrelated thread is not evidence that Nubrick caused the crash.
        return threads.contains { thread in
            thread.isMain == true && thread.stacktrace?.contains(where: isNubrickFrame) == true
        }
    }

    return crashEvent.exceptions.contains { exception in
        exception.callStacks?.contains(where: isNubrickFrame) == true
    }
}

struct TrackEventMeta: Codable, Equatable {
    var appId: String?
    var appVersion: String?
    var cfBundleVersion: String?
    var osName: String?
    var osVersion: String?
    var sdkVersion: String?
    var platform: String? = "ios"

    @MainActor
    static func current() -> TrackEventMeta {
        TrackEventMeta(
            appId: Bundle.main.bundleIdentifier ?? "",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            cfBundleVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            sdkVersion: NubrickConstants.sdkVersion
        )
    }
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

func makeJsonString(_ value: Any) throws -> String {
    let data = try JSONEncoder().encode(JSON(value: value))
    return String(data: data, encoding: .utf8) ?? "null"
}

/// Compute image_addr (load address) from a MetricKit frame.
/// Sentry wants `image_addr` in hex.
func imageAddrHex(addressDec: UInt64, offsetIntoTextDec: UInt64) -> String? {
    guard addressDec >= offsetIntoTextDec else { return nil } // invalid
    let load = addressDec - offsetIntoTextDec
    return hex(load)
}


/// Outbox retries only help for transient failures. 4xx other than 408/429 will
/// not succeed on a later attempt, so those records should be dropped.
func isRetryableTrackingStatusCode(_ statusCode: Int) -> Bool {
    statusCode >= 500 || statusCode == 408 || statusCode == 429
}

struct PendingTrackEvent {
    let eventID: String
    let event: TrackEvent
    let payloadSize: Int
    let userId: String?
    let meta: TrackEventMeta?
}

struct TrackOutboxLimits: Sendable {
    let maxQueueSize: Int
    let maxQueueBytes: Int
    let maxEventPayloadBytes: Int

    init(
        maxQueueSize: Int = 5_000,
        maxQueueBytes: Int = 10 * 1024 * 1024,
        maxEventPayloadBytes: Int = 500 * 1024
    ) {
        self.maxQueueSize = maxQueueSize
        self.maxQueueBytes = maxQueueBytes
        self.maxEventPayloadBytes = maxEventPayloadBytes
    }
}

final class TrackOutbox {
    private let persistentContainer: NSPersistentContainer
    private let limits: TrackOutboxLimits

    init(
        persistentContainer: NSPersistentContainer,
        limits: TrackOutboxLimits = TrackOutboxLimits()
    ) {
        self.persistentContainer = persistentContainer
        self.limits = limits
    }

    func insertAndGetPendingCount(
        _ event: TrackEvent,
        userId: String,
        meta: TrackEventMeta,
        enqueuedAt: Date = getCurrentDate()
    ) -> Int? {
        guard let payload = try? JSONEncoder().encode(event) else {
            trackWarn("Dropping tracking event because it could not be persisted.")
            return nil
        }
        guard payload.count <= limits.maxEventPayloadBytes else {
            trackWarn("Dropping oversized tracking event.")
            return nil
        }
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            trackWarn("Dropping tracking event because the outbox store is unavailable.")
            return nil
        }

        let context = persistentContainer.newBackgroundContext()
        let limits = limits
        let eventID = event.eventUuid
        let eventType = event.typename
        let metaPayload = try? JSONEncoder().encode(meta)
        return context.performAndWait {
            do {
                try Self.enforceLimits(in: context, limits: limits, incomingByteCount: payload.count)

                let entity = PendingTrackEventEntity(context: context)
                entity.eventID = eventID
                entity.payload = payload
                entity.eventType = eventType.rawValue
                entity.byteCount = Int64(payload.count)
                entity.createdAt = enqueuedAt
                entity.userId = userId
                entity.metaPayload = metaPayload
                try context.save()

                let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
                return try Self.count(in: context, for: request)
            } catch {
                context.rollback()
                trackWarn("Dropping tracking event because the outbox could not be saved: \(error)")
                return nil
            }
        }
    }

    /// Returns the oldest events in FIFO order. Crash payloads remain isolated,
    /// but do not overtake events that were queued earlier.
    func nextBatch(maxEvents: Int, maxPayloadBytes: Int) throws -> [PendingTrackEvent] {
        let entries = try fetch(limit: maxEvents)
        guard let first = entries.first else { return [] }
        if first.event.typename == .Crash {
            return [first]
        }

        var batch = [PendingTrackEvent]()
        var payloadBytes = 0
        for entry in entries {
            if entry.event.typename == .Crash {
                break
            }
            if entry.userId != first.userId || entry.meta != first.meta {
                break
            }
            if !batch.isEmpty && (
                payloadBytes > maxPayloadBytes ||
                entry.payloadSize > maxPayloadBytes - payloadBytes
            ) {
                break
            }
            batch.append(entry)
            payloadBytes += entry.payloadSize
        }
        return batch
    }

    func remove(eventIDs: [String]) -> Bool {
        guard !eventIDs.isEmpty else { return true }
        let context = persistentContainer.newBackgroundContext()
        return context.performAndWait {
            let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
            request.predicate = NSPredicate(format: "eventID IN %@", eventIDs)
            do {
                for entity in try context.fetch(request) {
                    context.delete(entity)
                }
                try context.save()
                return true
            } catch {
                context.rollback()
                trackWarn("Could not remove delivered tracking events from the outbox: \(error)")
                return false
            }
        }
    }

    func hasPendingEvents() throws -> Bool {
        let context = persistentContainer.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
            request.fetchLimit = 1
            return try Self.count(in: context, for: request) > 0
        }
    }

    private func fetch(limit: Int) throws -> [PendingTrackEvent] {
        let context = persistentContainer.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            do {
                var pending = [PendingTrackEvent]()
                for entity in try context.fetch(request) {
                    guard let event = try? JSONDecoder().decode(TrackEvent.self, from: entity.payload) else {
                        context.delete(entity)
                        trackWarn("Dropping corrupt tracking event from the outbox.")
                        continue
                    }
                    guard entity.byteCount >= 0, entity.byteCount == Int64(entity.payload.count) else {
                        context.delete(entity)
                        trackWarn("Dropping tracking event with an invalid payload size from the outbox.")
                        continue
                    }
                    let meta: TrackEventMeta?
                    if let metaPayload = entity.metaPayload {
                        meta = try? JSONDecoder().decode(TrackEventMeta.self, from: metaPayload)
                    } else {
                        meta = nil
                    }
                    pending.append(PendingTrackEvent(
                        eventID: entity.eventID,
                        event: event,
                        payloadSize: Int(entity.byteCount),
                        userId: entity.userId,
                        meta: meta
                    ))
                }
                if context.hasChanges {
                    try context.save()
                }
                return pending
            } catch {
                context.rollback()
                trackWarn("Could not read tracking events from the outbox: \(error)")
                throw error
            }
        }
    }

    private static func enforceLimits(
        in context: NSManagedObjectContext,
        limits: TrackOutboxLimits,
        incomingByteCount: Int
    ) throws {
        let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        var totalCount = try count(in: context, for: request)
        var totalBytes = try totalPendingBytes(in: context)
        var didEvict = false

        let oldestRequest = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        oldestRequest.fetchLimit = 1
        oldestRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        while totalCount >= limits.maxQueueSize || exceedsByteLimit(
            totalBytes: totalBytes,
            incomingByteCount: incomingByteCount,
            limit: limits.maxQueueBytes
        ) {
            guard let entry = try context.fetch(oldestRequest).first else {
                break
            }
            let entryByteCount = Int(entry.byteCount)
            guard entryByteCount >= 0 else {
                throw TrackOutboxError.invalidByteCount
            }
            totalCount -= 1
            totalBytes -= entryByteCount
            context.delete(entry)
            didEvict = true
        }
        if didEvict {
            trackWarn("Discarded oldest pending tracking events because the outbox limit was reached.")
        }
    }

    private static func count(
        in context: NSManagedObjectContext,
        for request: NSFetchRequest<PendingTrackEventEntity>
    ) throws -> Int {
        let count = try context.count(for: request)
        guard count != NSNotFound else {
            throw TrackOutboxError.countFailed
        }
        return count
    }

    private static func exceedsByteLimit(
        totalBytes: Int,
        incomingByteCount: Int,
        limit: Int
    ) -> Bool {
        totalBytes > limit || incomingByteCount > limit - totalBytes
    }

    private static func totalPendingBytes(in context: NSManagedObjectContext) throws -> Int {
        let totalByteCount = NSExpressionDescription()
        totalByteCount.name = "totalByteCount"
        totalByteCount.expression = NSExpression(
            forFunction: "sum:",
            arguments: [NSExpression(forKeyPath: "byteCount")]
        )
        totalByteCount.expressionResultType = .integer64AttributeType

        let request = NSFetchRequest<NSDictionary>(entityName: "NativebrikPendingTrackEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [totalByteCount]
        let result = try context.fetch(request)
        let byteCount = result.first?[totalByteCount.name] as? NSNumber
        let totalBytes = byteCount.map { Int($0.int64Value) } ?? 0
        guard totalBytes >= 0 else {
            throw TrackOutboxError.invalidByteCount
        }
        // Core Data can saturate an overflowing integer aggregate at Int.max.
        if totalBytes == .max {
            return try exactTotalPendingBytes(in: context)
        }
        return totalBytes
    }

    private static func exactTotalPendingBytes(in context: NSManagedObjectContext) throws -> Int {
        let request = NSFetchRequest<NSDictionary>(entityName: "NativebrikPendingTrackEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["byteCount"]

        var totalBytes = 0
        for result in try context.fetch(request) {
            guard let byteCount = result["byteCount"] as? NSNumber,
                  let byteCountValue = Int(exactly: byteCount.int64Value),
                  byteCountValue >= 0 else {
                throw TrackOutboxError.invalidByteCount
            }
            let (updatedTotal, overflow) = totalBytes.addingReportingOverflow(byteCountValue)
            guard !overflow else {
                throw TrackOutboxError.invalidByteCount
            }
            totalBytes = updatedTotal
        }
        return totalBytes
    }
}

private enum TrackOutboxError: Error {
    case countFailed
    case invalidByteCount
}

actor TrackRespositoryImpl: TrackRepository2 {
    private let maxBatchSize = 50
    private let maxBatchPayloadBytes = 512 * 1024
    private let maxBatchEventPayloadBytes = 500 * 1024
    private let flushInterval: TimeInterval = 10
    private let config: Config
    private let user: NubrickUser
    private let outbox: TrackOutbox
    private let trackingHTTPClient: any HTTPClient
    private var flushTask: Task<Void, Never>?
    private var scheduledFlushID: UUID?
    private var isSending = false
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private var retryDelay: TimeInterval = 10

    init(
        config: Config,
        user: NubrickUser,
        persistentContainer: NSPersistentContainer,
        trackingHTTPClient: any HTTPClient = trackingSession
    ) {
        self.config = config
        self.user = user
        self.outbox = TrackOutbox(persistentContainer: persistentContainer)
        self.trackingHTTPClient = trackingHTTPClient
    }

    private func makeJsonRequest<Body: Encodable>(
        url: URL,
        body: Body
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func trackExperimentEvent(_ event: TrackExperimentEvent) async {
        await enqueue(TrackEvent(
            typename: .Experiment,
            experimentId: event.experimentId,
            variantId: event.variantId,
            timestamp: getCurrentDate().ISO8601Format(),
            eventUuid: UUID().uuidString
        ))
    }
    
    func trackEvent(_ event: TrackUserEvent) async {
        await enqueue(TrackEvent(
            typename: .Event,
            name: event.name,
            timestamp: getCurrentDate().ISO8601Format(),
            eventUuid: UUID().uuidString
        ))
    }

    func flushNow() async {
        flushTask?.cancel()
        flushTask = nil
        scheduledFlushID = nil
        await drainOutbox()
    }

    private func enqueue(_ event: TrackEvent) async {
        let (userId, meta) = await MainActor.run {
            (self.user.id, TrackEventMeta.current())
        }
        enqueue(event, userId: userId, meta: meta)
    }

    private func enqueue(_ event: TrackEvent, userId: String, meta: TrackEventMeta) {
        guard let pendingEventCount = outbox.insertAndGetPendingCount(event, userId: userId, meta: meta) else { return }
        if pendingEventCount >= maxBatchSize {
            requestFlush(after: 0)
        } else {
            requestFlush(after: flushInterval)
        }
    }

    private func requestFlush(after delay: TimeInterval) {
        guard !isSending else { return }
        if flushTask != nil {
            guard delay == 0 else { return }
            flushTask?.cancel()
            flushTask = nil
            scheduledFlushID = nil
        }
        let flushID = UUID()
        scheduledFlushID = flushID
        flushTask = Task { [weak self] in
            guard let self else { return }
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self.runScheduledFlush(id: flushID)
        }
    }

    private func runScheduledFlush(id: UUID) async {
        guard scheduledFlushID == id else { return }
        flushTask = nil
        scheduledFlushID = nil
        await drainOutbox()
    }

    private func drainOutbox() async {
        if isSending {
            await withCheckedContinuation { continuation in
                drainWaiters.append(continuation)
            }
            return
        }

        isSending = true
        var retryAfter: TimeInterval?

        do {
            while try outbox.hasPendingEvents() {
                if try await sendNextBatch() {
                    retryDelay = 10
                    continue
                }

                let delay = retryDelay
                retryDelay = min(retryDelay * 2, 5 * 60)
                retryAfter = delay
                break
            }
        } catch {
            trackWarn("Could not drain the tracking outbox: \(error)")
            let delay = retryDelay
            retryDelay = min(retryDelay * 2, 5 * 60)
            retryAfter = delay
        }

        isSending = false
        let waiters = drainWaiters
        drainWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        if let retryAfter {
            requestFlush(after: retryAfter)
        }
    }

    private func sendNextBatch() async throws -> Bool {
        let pending: [PendingTrackEvent]
        pending = try outbox.nextBatch(maxEvents: maxBatchSize, maxPayloadBytes: maxBatchEventPayloadBytes)
        guard !pending.isEmpty else { return true }

        do {
            let (liveUserId, liveMeta) = await MainActor.run {
                (self.user.id, TrackEventMeta.current())
            }
            let userID = pending[0].userId ?? liveUserId
            let meta = pending[0].meta ?? liveMeta
            var batch = pending

            while !batch.isEmpty {
                let trackRequest = TrackRequest(
                    projectId: config.projectId,
                    userId: userID,
                    timestamp: getCurrentDate().ISO8601Format(),
                    events: batch.map(\.event),
                    meta: meta
                )
                let url = URL(string: config.trackUrl)!
                let request = try makeJsonRequest(url: url, body: trackRequest)
                if request.httpBody?.count ?? 0 <= maxBatchPayloadBytes {
                    let (_, response) = try await trackingHTTPClient.fetchData(for: request)
                    guard let response = response as? HTTPURLResponse else {
                        return false
                    }
                    if (200...299).contains(response.statusCode) {
                        return outbox.remove(eventIDs: batch.map(\.eventID))
                    }
                    if isRetryableTrackingStatusCode(response.statusCode) {
                        return false
                    }
                    trackWarn("Dropping tracking batch after a non-retryable HTTP \(response.statusCode) response.")
                    return outbox.remove(eventIDs: batch.map(\.eventID))
                }

                guard batch.count > 1 else {
                    trackWarn("Dropping oversized tracking event.")
                    return outbox.remove(eventIDs: batch.map(\.eventID))
                }
                batch.removeLast()
            }
            return true
        } catch {
            return false
        }
    }
    
    func processMetricKitCrash(
        callStackTreeJSON: Data,
        terminationReason: String?,
        exceptionType: UInt32?
    ) async {
        if let callStackTree = try? JSONDecoder().decode(
            CallStackTree.self,
            from: callStackTreeJSON
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

                    // `threadAttributed` identifies the thread where MetricKit
                    // observed the crash. Retain the `isMain` JSON key for
                    // backend compatibility.
                    let isCrashAttributedThread = currentCallStack.threadAttributed ?? false
                    threads.append(ThreadRecord(
                        isMain: isCrashAttributedThread,
                        stacktrace: threadFrames
                    ))

                    // Keep crash-attributed thread frames for the exception record.
                    if isCrashAttributedThread {
                        mainThreadFrames = threadFrames
                    }
                }
            }

            let exceptionRecord = ExceptionRecord(
                type: exceptionTypeString(exceptionType),
                message: terminationReason,
                callStacks: mainThreadFrames
            )

            let crashEvent = TrackCrashEvent(
                exceptions: [exceptionRecord],
                threads: threads,
                platform: "ios"
            )
            await sendCrashToBackend(crashEvent)
        }
    }

    private func sendCrashToBackend(_ crashEvent: TrackCrashEvent) async {
        let (userId, meta) = await MainActor.run {
            (self.user.id, TrackEventMeta.current())
        }
        let causedByNativebrik = isNubrickCausedCrash(crashEvent)

        // Only send error tracking events for error or fatal severity
        if crashEvent.severity.isErrorLevel {
            enqueue(TrackEvent(
                typename: .Event,
                name: TriggerEventNameDefs.N_ERROR_RECORD.rawValue,
                timestamp: getCurrentDate().ISO8601Format(),
                platform: nil,
                eventUuid: UUID().uuidString
            ), userId: userId, meta: meta)
        }
        if causedByNativebrik {
            if crashEvent.severity.isErrorLevel {
                enqueue(TrackEvent(
                    typename: .Event,
                    name: TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD.rawValue,
                    timestamp: getCurrentDate().ISO8601Format(),
                    platform: nil,
                    eventUuid: UUID().uuidString
                ), userId: userId, meta: meta)
            }
            enqueue(TrackEvent(
                typename: .Crash,
                timestamp: getCurrentDate().ISO8601Format(),
                exceptions: crashEvent.exceptions,
                threads: crashEvent.threads,
                platform: crashEvent.platform,
                flutterSdkVersion: crashEvent.flutterSdkVersion,
                severity: crashEvent.severity.rawValue,
                eventUuid: UUID().uuidString
            ), userId: userId, meta: meta)
        }
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) async {
        await sendCrashToBackend(crashEvent)
    }

    func sendSurveyResponse(experimentId: String, variantId: String, response_data: String) async {
        guard !experimentId.isEmpty, !variantId.isEmpty else {
            return
        }
        let userID = await MainActor.run {
            self.user.id
        }

        do {
            let requestBody = SurveyResponseRequest(
                timestamp: getCurrentDate().ISO8601Format(),
                projectId: self.config.projectId,
                experimentId: experimentId,
                variantId: variantId,
                userId: userID,
                response_data: response_data,
                meta: await TrackEventMeta.current()
            )
            let url = URL(string: config.surveyResponsesUrl)!
            let request = try makeJsonRequest(url: url, body: requestBody)
            let _ = try await trackingSession.data(for: request)
        } catch {
            // Form submissions are one-shot; keep the event pipeline unaffected on failure.
            return
        }
    }
}
