import Foundation

/// One experiment flow, independent of how its pages are presented.
@MainActor
final class TriggerExperimentSession {
    private enum RecordingState {
        case notRecorded
        case recording
        case recorded
    }

    private(set) var id: String?
    private var running = false
    private var recording = RecordingState.notRecorded

    var isActive: Bool { self.id != nil }

    func owns(_ id: String) -> Bool { self.id == id && self.running }

    func start(_ id: String = UUID().uuidString) -> String? {
        guard !id.isEmpty, self.id == nil else { return nil }
        self.id = id
        self.running = true
        self.recording = .notRecorded
        return id
    }

    func beginRecording(_ id: String) -> Bool {
        guard self.owns(id), case .notRecorded = self.recording else { return false }
        self.recording = .recording
        return true
    }

    func finishRecording(_ id: String) {
        guard self.id == id, case .recording = self.recording else { return }
        self.recording = .recorded
    }

    func finish(_ id: String) {
        guard self.id == id else { return }
        self.running = false
    }

    func reset() {
        self.id = nil
        self.running = false
        self.recording = .notRecorded
    }

    func releaseIfFinished() {
        guard !self.running else { return }
        if case .recording = self.recording { return }
        self.id = nil
    }
}
