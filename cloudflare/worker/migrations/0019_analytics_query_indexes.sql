-- Keep admin telemetry queries bounded as real visitor data accumulates.
CREATE INDEX IF NOT EXISTS idx_clickstream_events_created_at
    ON analytics_clickstream_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clickstream_events_type_created_at
    ON analytics_clickstream_events(event_type, created_at DESC);
