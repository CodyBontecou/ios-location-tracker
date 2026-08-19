import XCTest
@testable import IsoMe

/// Reproduces the on-device crash reported when picking an interval in the
/// AUTO EXPORT REPEAT picker: the picker binding sets `intervalHours`, which
/// runs the full scheduling path synchronously on the main actor.
final class IntervalPickerCrashReproTests: XCTestCase {
    @MainActor
    func testSettingIntervalHoursWhileEnabledDoesNotCrash() {
        let scheduler = DailyExportScheduler.shared
        scheduler.setEnabledFromUserSetup(true)
        scheduler.intervalHours = 1
        scheduler.intervalHours = 3
        scheduler.intervalHours = 0
        // Regression: didSet used to self-assign clamped values, which recursed
        // infinitely through Combine's Published subscript and crashed.
        scheduler.intervalHours = 24
        scheduler.intervalHours = -5
        scheduler.intervalHours = 0
        scheduler.setEnabledFromUserSetup(false)
    }
}
