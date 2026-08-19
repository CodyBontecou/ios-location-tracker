import Foundation

/// App-side occurrence math for interval (intraday) scheduled exports.
///
/// The cycle resets every 24 hours at the daily anchor (hour:minute, local
/// wall clock): occurrences fire at `anchor + k × intervalHours` for every `k`
/// with `k × intervalHours < 24h`. Intervals that do not divide 24 (9h, 23h,
/// …) simply end their cycle early; the next cycle begins at the next daily
/// anchor. A cycle's tail can spill past midnight, so occurrence enumeration
/// around any instant considers the anchor days on both sides.
///
/// The equivalent server-side implementation lives in
/// `worker/scheduled-notifications/src/scheduling.ts` (`computeNextFire`).
enum IntervalExportScheduleDateMath {
    static let minIntervalHours = 1
    static let maxIntervalHours = 23

    /// Clamps an interval in hours to the supported range. `0` (once daily) is
    /// preserved; positive values clamp to 1…23.
    static func clampIntervalHours(_ hours: Int) -> Int {
        hours <= 0 ? 0 : min(max(hours, minIntervalHours), maxIntervalHours)
    }

    /// Largest step index `k` with `k × intervalHours` strictly below 24 hours.
    static func maxStepIndex(intervalHours: Int) -> Int {
        let hours = clampIntervalHours(intervalHours)
        return 24 % hours == 0 ? 24 / hours - 1 : 24 / hours
    }

    /// All occurrences within the cycle anchored on the local day of `anchorDay`.
    static func occurrences(
        anchorHour: Int,
        anchorMinute: Int,
        intervalHours: Int,
        anchorDay: Date,
        calendar: Calendar
    ) -> [Date] {
        var components = calendar.dateComponents([.year, .month, .day], from: anchorDay)
        components.hour = anchorHour
        components.minute = anchorMinute
        components.second = 0
        guard let anchor = calendar.date(from: components) else { return [] }

        let hours = clampIntervalHours(intervalHours)
        return (0...maxStepIndex(intervalHours: intervalHours)).compactMap {
            calendar.date(byAdding: .hour, value: $0 * hours, to: anchor)
        }
    }

    /// First occurrence strictly after `now`.
    static func nextOccurrence(
        anchorHour: Int,
        anchorMinute: Int,
        intervalHours: Int,
        after now: Date,
        calendar: Calendar
    ) -> Date? {
        var best: Date?
        // Yesterday's cycle tail can spill into today, so consider the anchor
        // day before and after `now` as well as today itself.
        for dayOffset in [-1, 0, 1] {
            guard let anchorDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for occurrence in occurrences(
                anchorHour: anchorHour,
                anchorMinute: anchorMinute,
                intervalHours: intervalHours,
                anchorDay: anchorDay,
                calendar: calendar
            ) where occurrence > now {
                if best == nil || occurrence < best! {
                    best = occurrence
                }
            }
        }
        return best
    }

    /// Most recent occurrence at or before `now`.
    static func latestOccurrence(
        anchorHour: Int,
        anchorMinute: Int,
        intervalHours: Int,
        at now: Date,
        calendar: Calendar
    ) -> Date? {
        var best: Date?
        for dayOffset in [-1, 0] {
            guard let anchorDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for occurrence in occurrences(
                anchorHour: anchorHour,
                anchorMinute: anchorMinute,
                intervalHours: intervalHours,
                anchorDay: anchorDay,
                calendar: calendar
            ) where occurrence <= now {
                if best == nil || occurrence > best! {
                    best = occurrence
                }
            }
        }
        return best
    }
}
