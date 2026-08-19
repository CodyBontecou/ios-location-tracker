-- Interval schedules: fire multiple silent pushes per day.
--
-- The cycle resets every 24 hours at the daily anchor (hour:minute in the
-- install's timezone). Occurrences fire at anchor + k * interval while
-- k * interval < 24h. SQLite cannot alter CHECK constraints, so rebuild the
-- schedules table with the extended frequency domain and a nullable
-- interval_minutes column (60..1380 = 1..23 hours).

CREATE TABLE IF NOT EXISTS schedules_new (
  user_id         TEXT PRIMARY KEY,
  is_enabled      INTEGER NOT NULL,
  frequency       TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'interval')),
  hour            INTEGER NOT NULL CHECK (hour BETWEEN 0 AND 23),
  minute          INTEGER NOT NULL CHECK (minute BETWEEN 0 AND 59),
  weekday         INTEGER CHECK (weekday IS NULL OR weekday BETWEEN 1 AND 7),
  interval_minutes INTEGER CHECK (interval_minutes IS NULL OR (interval_minutes >= 60 AND interval_minutes <= 1380)),
  timezone        TEXT NOT NULL,
  next_fire_at    INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

INSERT INTO schedules_new
  (user_id, is_enabled, frequency, hour, minute, weekday, interval_minutes, timezone, next_fire_at, updated_at)
SELECT user_id, is_enabled, frequency, hour, minute, weekday, NULL, timezone, next_fire_at, updated_at
  FROM schedules;

DROP TABLE schedules;
ALTER TABLE schedules_new RENAME TO schedules;

CREATE INDEX IF NOT EXISTS idx_schedules_due
  ON schedules(is_enabled, next_fire_at);
