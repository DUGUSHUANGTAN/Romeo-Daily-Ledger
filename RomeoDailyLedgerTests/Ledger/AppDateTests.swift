import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("App date normalization")
struct AppDateTests {
    @Test func normalizesToInjectedZoneStartOfDayAndIsIdempotent() throws {
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let normalizer = AppDateNormalizer(timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone))
        let instant = try #require(ISO8601DateFormatter().date(from: "2024-02-29T18:45:00Z"))
        let expected = try #require(ISO8601DateFormatter().date(from: "2024-02-29T16:00:00Z"))
        let normalized = normalizer.normalize(instant)
        #expect(normalized == expected)
        #expect(normalizer.normalize(normalized) == normalized)
    }

    @Test func todayUsesInjectedClockAcrossTimeZones() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2024-03-01T00:30:00Z"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let shanghai = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let clock = FixedAppClock(now: instant)
        let west = AppDateNormalizer(clock: clock, timeZoneProvider: FixedAppTimeZoneProvider(timeZone: losAngeles))
        let east = AppDateNormalizer(clock: clock, timeZoneProvider: FixedAppTimeZoneProvider(timeZone: shanghai))
        #expect(west.localDateString(for: west.today) == "2024-02-29")
        #expect(east.localDateString(for: east.today) == "2024-03-01")
    }

    @Test func relativeDatesHandleMonthEndAndLeapYear() throws {
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let instant = try #require(ISO8601DateFormatter().date(from: "2024-03-01T04:00:00Z"))
        let normalizer = AppDateNormalizer(clock: FixedAppClock(now: instant), timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone))
        #expect(normalizer.localDateString(for: normalizer.yesterday) == "2024-02-29")
        #expect(normalizer.localDateString(for: normalizer.startOfCurrentMonth) == "2024-03-01")
    }
}
