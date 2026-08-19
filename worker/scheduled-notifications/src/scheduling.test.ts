import { describe, expect, it } from "vitest";
import {
  computeNextFire,
  getZonedParts,
  tzOffsetMinutes,
  zonedTimeToUtcMs,
} from "./scheduling";

function sec(iso: string): number {
  return Math.floor(new Date(iso).getTime() / 1000);
}

describe("timezone date math", () => {
  it("extracts wall-clock parts in the target zone", () => {
    const parts = getZonedParts(Date.UTC(2026, 4, 4, 12, 0), "America/Los_Angeles");
    expect(parts.year).toBe(2026);
    expect(parts.month).toBe(5);
    expect(parts.day).toBe(4);
    expect(parts.hour).toBe(5);
    expect(parts.weekday).toBe(1);
  });

  it("returns daylight-saving-aware offsets", () => {
    expect(tzOffsetMinutes("America/Los_Angeles", Date.UTC(2026, 0, 15))).toBe(-480);
    expect(tzOffsetMinutes("America/Los_Angeles", Date.UTC(2026, 6, 15))).toBe(-420);
  });

  it("converts zoned wall-clock time to UTC", () => {
    expect(new Date(zonedTimeToUtcMs(2026, 7, 15, 9, 0, "America/Los_Angeles")).toISOString())
      .toBe("2026-07-15T16:00:00.000Z");
  });
});

describe("computeNextFire", () => {
  it("fires daily today when the selected time is still ahead", () => {
    const next = computeNextFire(
      { frequency: "daily", hour: 9, minute: 0 },
      "America/Los_Angeles",
      sec("2026-05-04T12:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T16:00:00.000Z");
  });

  it("rolls daily schedules to tomorrow when today's slot passed", () => {
    const next = computeNextFire(
      { frequency: "daily", hour: 9, minute: 0 },
      "America/Los_Angeles",
      sec("2026-05-04T17:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-05T16:00:00.000Z");
  });

  it("fires weekly on the configured ISO weekday", () => {
    const next = computeNextFire(
      { frequency: "weekly", hour: 9, minute: 0, weekday: 3 },
      "America/Los_Angeles",
      sec("2026-05-04T12:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-06T16:00:00.000Z");
  });

  it("requires weekday for weekly schedules", () => {
    expect(() => computeNextFire(
      { frequency: "weekly", hour: 9, minute: 0 },
      "UTC",
      sec("2026-05-04T12:00:00Z"),
    )).toThrow();
  });
});

describe("computeNextFire (interval)", () => {
  it("fires the next interval slot within the anchor day", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 180 },
      "America/Los_Angeles",
      sec("2026-05-04T14:30:00Z"), // 07:30 local — anchor has not started
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T16:00:00.000Z"); // 09:00
  });

  it("advances through the day every interval", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 180 },
      "America/Los_Angeles",
      sec("2026-05-04T17:00:00Z"), // 10:00 local — past 09:00 slot
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T19:00:00.000Z"); // 12:00
  });

  it("continues the cycle past midnight, then resets at the next anchor", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 180 },
      "America/Los_Angeles",
      sec("2026-05-05T04:30:00Z"), // 21:30 local — 21:00 slot passed
    );
    // anchor + 15h = next local day 00:00 = 07:00Z
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-05T07:00:00.000Z");
  });

  it("supports intervals that do not divide 24h (9h tail spills past midnight)", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 540 },
      "America/Los_Angeles",
      sec("2026-05-04T05:00:00Z"), // 22:00 local — 18:00 slot passed
    );
    // anchor + 18h = next local day 03:00 = 10:00Z
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T10:00:00.000Z");
  });

  it("supports 23h intervals (two fires per cycle)", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 1380 },
      "America/Los_Angeles",
      sec("2026-05-04T16:00:00Z"), // 09:00 local — anchor just fired
    );
    // anchor + 23h = next local day 08:00 = 15:00Z
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-05T15:00:00.000Z");
  });

  it("handles 1h intervals with 24 slots per cycle", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 30, intervalMinutes: 60 },
      "UTC",
      sec("2026-05-04T09:30:00Z"), // exactly at the anchor
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T10:30:00.000Z");
  });

  it("clamps invalid interval minutes defensively", () => {
    const next = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 5 },
      "UTC",
      sec("2026-05-04T00:00:00Z"),
    );
    // clamped to 60 → hourly; yesterday's cycle tail reaches into today: 01:00
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T01:00:00.000Z");
  });

  it("crosses DST without skipping the anchor", () => {
    // US DST starts 2026-03-08 02:00 local (PT jumps 02:00 → 03:00); 09:00 is PDT
    const before = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 720 },
      "America/Los_Angeles",
      sec("2026-03-08T09:30:00Z"), // 01:30 PST
    );
    expect(new Date(before * 1000).toISOString()).toBe("2026-03-08T16:00:00.000Z"); // 09:00 PDT

    const after = computeNextFire(
      { frequency: "interval", hour: 9, minute: 0, intervalMinutes: 720 },
      "America/Los_Angeles",
      sec("2026-03-09T17:30:00Z"), // 10:30 PDT (UTC-7)
    );
    // 09:00 slot passed → anchor + 12h = 21:00 PDT = next day 04:00Z
    expect(new Date(after * 1000).toISOString()).toBe("2026-03-10T04:00:00.000Z");
  });
});
