import CoreData
import Foundation
import XCTest
@testable import NubrickLocal

@MainActor
final class DatabaseFrequencyTests: XCTestCase {
    @MainActor
    func testRepositoryWaitsForPersistentContainerReadiness() async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }

        let provider = DeferredPersistentContainerProvider()
        let repository = DatabaseRepositoryImpl(persistentContainerProvider: provider)
        let appendTask = Task {
            await repository.appendUserEvent(name: "event-before-ready")
        }

        await provider.waitUntilRequested()
        let request = NSFetchRequest<UserEventEntity>(entityName: "NativebrikUserEvent")
        XCTAssertEqual(try persistentContainer.viewContext.count(for: request), 0)

        await provider.resolve(with: persistentContainer)
        await appendTask.value

        XCTAssertEqual(try persistentContainer.viewContext.count(for: request), 1)
    }

    func testRepositoryRejectsExperimentsWhenPersistentContainerFails() async {
        let provider = DeferredPersistentContainerProvider()
        let repository = DatabaseRepositoryImpl(persistentContainerProvider: provider)

        let frequencyTask = Task {
            await repository.isNotInFrequency(experimentId: "experiment", frequency: nil)
        }
        await provider.waitUntilRequested()
        await provider.resolve(with: nil)

        let isNotInFrequency = await frequencyTask.value
        XCTAssertFalse(isNotInFrequency)
        let userEventFrequencyMatches = await repository.isMatchedToUserEventFrequencyCondition(condition: nil)
        XCTAssertFalse(userEventFrequencyMatches)
    }

    func testDailyExperimentFrequencyAllowsDisplayOnTheNextLocalDay() async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }

        let originalOffset = __for_test_get_datetime_offset()
        defer { __for_test_sync_datetime_offset(offset: originalOffset) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let displayedAt = try XCTUnwrap(
            calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())
        )
        setCurrentDate(displayedAt)

        let repository = DatabaseRepositoryImpl(persistentContainer: persistentContainer)
        await repository.appendExperimentHistory(experimentId: "daily-experiment")

        let blockedOnSameDay = await repository.isNotInFrequency(
            experimentId: "daily-experiment",
            frequency: ExperimentFrequency(period: 1, unit: .DAY)
        )
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: displayedAt))
        setCurrentDate(nextDay)
        let allowed = await repository.isNotInFrequency(
            experimentId: "daily-experiment",
            frequency: ExperimentFrequency(period: 1, unit: .DAY)
        )

        XCTAssertFalse(blockedOnSameDay)
        XCTAssertTrue(allowed)
    }

    func testWeeklyExperimentFrequencyAllowsDisplayInTheNextCalendarWeek() async throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }

        let originalOffset = __for_test_get_datetime_offset()
        defer { __for_test_sync_datetime_offset(offset: originalOffset) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let weekStart = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: Date())?.start)
        let displayedAt = try XCTUnwrap(calendar.date(byAdding: .hour, value: 60, to: weekStart))
        setCurrentDate(displayedAt)
        await repository.appendExperimentHistory(experimentId: "weekly-experiment")

        let nextWeek = try XCTUnwrap(calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart))
        setCurrentDate(try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: nextWeek)))
        let allowed = await repository.isNotInFrequency(
            experimentId: "weekly-experiment",
            frequency: ExperimentFrequency(period: 1, unit: .WEEK)
        )

        XCTAssertTrue(allowed)
    }

    func testMonthlyExperimentFrequencyAllowsDisplayInTheNextCalendarMonth() async throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }

        let originalOffset = __for_test_get_datetime_offset()
        defer { __for_test_sync_datetime_offset(offset: originalOffset) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let monthStart = try XCTUnwrap(calendar.dateInterval(of: .month, for: Date())?.start)
        let displayedAt = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: monthStart))
        setCurrentDate(displayedAt)
        await repository.appendExperimentHistory(experimentId: "monthly-experiment")

        let nextMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: monthStart))
        setCurrentDate(try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: nextMonth)))
        let allowed = await repository.isNotInFrequency(
            experimentId: "monthly-experiment",
            frequency: ExperimentFrequency(period: 1, unit: .MONTH)
        )

        XCTAssertTrue(allowed)
    }

    func testNonPositivePeriodsDoNotRestrictDelivery() async throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }

        let originalOffset = __for_test_get_datetime_offset()
        defer { __for_test_sync_datetime_offset(offset: originalOffset) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let displayedAt = try XCTUnwrap(
            calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())
        )
        setCurrentDate(displayedAt)
        await repository.appendExperimentHistory(experimentId: "hourly-experiment")

        for period in [0, -1] {
            let allowed = await repository.isNotInFrequency(
                experimentId: "hourly-experiment",
                frequency: ExperimentFrequency(period: period, unit: .HOUR)
            )

            XCTAssertTrue(allowed, "period=\(period)")
        }

    }

    func testMissingPeriodAllowsOnlyTheFirstDisplay() async throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }

        let frequency = ExperimentFrequency(unit: .DAY)
        let experimentId = "only-once-experiment"

        let allowedBeforeFirstDisplay = await repository.isNotInFrequency(
            experimentId: experimentId,
            frequency: frequency
        )
        await repository.appendExperimentHistory(experimentId: experimentId)
        let blockedAfterFirstDisplay = await repository.isNotInFrequency(
            experimentId: experimentId,
            frequency: frequency
        )

        XCTAssertTrue(allowedBeforeFirstDisplay)
        XCTAssertFalse(blockedAfterFirstDisplay)
    }

    private func makeRepository() throws -> (DatabaseRepositoryImpl, () -> Void) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        return (
            DatabaseRepositoryImpl(persistentContainer: persistentContainer),
            { self.closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        )
    }

    private func setCurrentDate(_ date: Date) {
        let offset = Int64(date.timeIntervalSince1970 * 1_000) - Int64(Date().timeIntervalSince1970 * 1_000)
        __for_test_sync_datetime_offset(offset: offset)
    }

    private func closeAndRemovePersistentStore(
        _ persistentContainer: NSPersistentContainer,
        at storeURL: URL
    ) {
        persistentContainer.viewContext.reset()
        for store in persistentContainer.persistentStoreCoordinator.persistentStores {
            try? persistentContainer.persistentStoreCoordinator.remove(store)
        }
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
    }
}

private actor DeferredPersistentContainerProvider: PersistentContainerProvider {
    private var persistentContainer: NSPersistentContainer?
    private var containerWaiters: [CheckedContinuation<NSPersistentContainer?, Never>] = []
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasRequestedContainer = false
    private var hasResolvedContainer = false

    func persistentContainer() async -> NSPersistentContainer? {
        hasRequestedContainer = true
        let requestWaiters = requestWaiters
        self.requestWaiters.removeAll()
        for waiter in requestWaiters {
            waiter.resume()
        }

        if hasResolvedContainer {
            return persistentContainer
        }

        return await withCheckedContinuation { containerWaiters.append($0) }
    }

    func waitUntilRequested() async {
        guard !hasRequestedContainer else { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func resolve(with persistentContainer: NSPersistentContainer?) {
        self.persistentContainer = persistentContainer
        hasResolvedContainer = true
        let containerWaiters = containerWaiters
        self.containerWaiters.removeAll()
        for waiter in containerWaiters {
            waiter.resume(returning: persistentContainer)
        }
    }
}
