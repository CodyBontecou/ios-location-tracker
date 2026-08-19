/**
 * Compute the next fire time for an export schedule as UTC unix seconds.
 *
 * Handles IANA timezones via Intl, including DST transitions. Daily schedules
 * fire today at hour:minute or tomorrow if that has passed. Weekly schedules
 * fire on ISO weekday 1 = Mon … 7 = Sun.
 */

export type Frequency = "daily" | "weekly" | "interval";

export interface Schedule {
  frequency: Frequency;
  hour: number;
  minute: number;
  weekday?: number;
  /** Required for frequency "interval": minutes between fires (60–1380). */
  intervalMinutes?: number;
}

export interface ZonedParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  weekday: number;
}

const ISO_WEEKDAY: Record<string, number> = {
  Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7,
};

export function getZonedParts(utcMs: number, tz: string): ZonedParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    weekday: "short",
    hourCycle: "h23",
  }).formatToParts(new Date(utcMs));
  const get = (type: string) => parts.find((p) => p.type === type)!.value;
  return {
    year: Number(get("year")),
    month: Number(get("month")),
    day: Number(get("day")),
    hour: Number(get("hour")),
    minute: Number(get("minute")),
    second: Number(get("second")),
    weekday: ISO_WEEKDAY[get("weekday")] ?? 0,
  };
}

export function tzOffsetMinutes(tz: string, utcMs: number): number {
  const z = getZonedParts(utcMs, tz);
  const asUtc = Date.UTC(z.year, z.month - 1, z.day, z.hour, z.minute, z.second);
  return Math.round((asUtc - utcMs) / 60000);
}

export function zonedTimeToUtcMs(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  tz: string,
): number {
  let guess = Date.UTC(year, month - 1, day, hour, minute);
  const offset1 = tzOffsetMinutes(tz, guess);
  guess -= offset1 * 60000;
  const offset2 = tzOffsetMinutes(tz, guess);
  if (offset2 !== offset1) guess -= (offset2 - offset1) * 60000;
  return guess;
}

export function computeNextFire(schedule: Schedule, tz: string, nowSec: number): number {
  const nowMs = nowSec * 1000;
  const z = getZonedParts(nowMs, tz);

  if (schedule.frequency === "interval") {
    return nextIntervalFireMs(schedule, z, tz, nowMs);
  }

  let candidate = zonedTimeToUtcMs(z.year, z.month, z.day, schedule.hour, schedule.minute, tz);
  let daysToAdd = 0;

  if (schedule.frequency === "daily") {
    if (candidate <= nowMs) daysToAdd = 1;
  } else {
    const target = schedule.weekday;
    if (target === undefined || target < 1 || target > 7) {
      throw new Error("Weekly schedule requires weekday in [1,7]");
    }
    daysToAdd = (target - z.weekday + 7) % 7;
    if (daysToAdd === 0 && candidate <= nowMs) daysToAdd = 7;
  }

  if (daysToAdd > 0) {
    candidate = zonedTimeToUtcMs(
      z.year,
      z.month,
      z.day + daysToAdd,
      schedule.hour,
      schedule.minute,
      tz,
    );
  }

  return Math.floor(candidate / 1000);
}

/**
 * Interval schedules: the cycle resets every 24h at the daily anchor.
 * Occurrences fire at anchor + k * interval while k * interval < 24h, so
 * intervals that do not divide 24 (9h, 23h, …) simply end their cycle early
 * and the next cycle begins at the next daily anchor. Because a cycle's tail
 * can spill past midnight, candidates from the previous and next anchor days
 * are considered.
 */
function nextIntervalFireMs(
  schedule: Schedule,
  z: ZonedParts,
  tz: string,
  nowMs: number,
): number {
  const intervalMinutes = clampIntervalMinutes(schedule.intervalMinutes);

  let best: number | null = null;
  for (const dayOffset of [-1, 0, 1]) {
    const anchorMs = zonedTimeToUtcMs(
      z.year,
      z.month,
      z.day + dayOffset,
      schedule.hour,
      schedule.minute,
      tz,
    );
    for (let k = 0; k * intervalMinutes < 24 * 60; k++) {
      const candidate = anchorMs + k * intervalMinutes * 60000;
      if (candidate > nowMs && (best === null || candidate < best)) {
        best = candidate;
      }
    }
  }

  if (best === null) {
    throw new Error("Interval schedule produced no next fire time");
  }
  return Math.floor(best / 1000);
}

export function clampIntervalMinutes(value: number | undefined): number {
  const raw = typeof value === "number" && Number.isFinite(value) ? Math.round(value) : 60;
  return Math.min(1380, Math.max(60, raw));
}
