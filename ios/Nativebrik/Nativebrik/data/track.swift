//
//  remote-config.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

private let CRASH_RECORD_KEY: String = "NATIVEBRIK_CRASH_RECORD"

struct CrashRecord: Codable {
    var reason: String?
    var callStacks: [String]?
}

protocol TrackRepository2 {
    func trackExperimentEvent(_ event: TrackExperimentEvent)
    func trackEvent(_ event: TrackUserEvent)

    func record(_ exception: NSException)
}

struct TrackRequest: Encodable {
    var projectId: String
    var userId: String
    var timestamp: DateTime
    var events: [TrackEvent]
}

struct TrackEvent: Encodable {
    enum Typename: String, Encodable {
        case Event = "event"
        case Experiment = "experiment"
    }
    var typename: Typename
    var experimentId: String?
    var variantId: String?
    var name: String?
    var timestamp: DateTime
}

struct TrackUserEvent {
    var name: String
}

struct TrackExperimentEvent {
    var experimentId: String
    var variantId: String
}


class TrackRespositoryImpl: TrackRepository2 {
    private let maxQueueSize: Int
    private let maxBatchSize: Int
    private let config: Config
    private let user: NativebrikUser
    private let queueLock: NSLock
    private var timer: Timer?
    private var buffer: [TrackEvent]
    init(config: Config, user: NativebrikUser) {
        self.maxQueueSize = 300
        self.maxBatchSize = 50
        self.config = config
        self.user = user
        self.queueLock = NSLock()
        self.buffer = []
        self.timer = nil

        self.report()
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
        let trackRequest = TrackRequest(
            projectId: self.config.projectId,
            userId: self.user.id,
            timestamp: formatToISO8601(getCurrentDate()),
            events: events
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

    private func report() {
        guard let data = self.user.userDB.data(forKey: CRASH_RECORD_KEY) else {
            return
        }
        do {
            self.user.userDB.removeObject(forKey: CRASH_RECORD_KEY)
            let crashRecord = try JSONDecoder().decode(CrashRecord.self, from: data)
            let causedByNativebrik = (
                crashRecord.callStacks?.contains(where: { callStack in
                return callStack.contains("Nativebrik")
            }) ?? false) || (crashRecord.reason?.contains("Nativebrik") ?? false)
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
            }

            Task(priority: .low) {
                try await self.sendAndFlush()
            }

        } catch {}
    }

    func record(_ exception: NSException) {
        let record = CrashRecord(
            reason: exception.reason,
            callStacks: exception.callStackSymbols
        )
        do {
            let json = try JSONEncoder().encode(record)
            self.user.userDB.set(json, forKey: CRASH_RECORD_KEY)
        } catch {}
    }
}
