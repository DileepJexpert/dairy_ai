-- 0017_visitor_telemetry.sql
-- Store live customer and visitor telemetry, geo coordinates, and clickstream events.

CREATE TABLE IF NOT EXISTS analytics_visitor_sessions (
    id TEXT PRIMARY KEY,
    session_id TEXT UNIQUE NOT NULL,
    customer_id TEXT,
    ip_address TEXT,
    country TEXT DEFAULT 'India',
    state TEXT,
    city TEXT,
    referrer TEXT,
    referrer_type TEXT DEFAULT 'direct',
    landing_page TEXT DEFAULT '/shop',
    device_type TEXT DEFAULT 'mobile',
    browser TEXT,
    os TEXT,
    page_views_count INTEGER DEFAULT 1,
    is_bounce INTEGER DEFAULT 1,
    started_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics_clickstream_events (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    customer_id TEXT,
    event_type TEXT NOT NULL,
    page_url TEXT NOT NULL,
    element_id TEXT,
    element_text TEXT,
    target_id TEXT,
    metadata_json TEXT,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_visitor_sessions_started_at ON analytics_visitor_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_last_seen_at ON analytics_visitor_sessions(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_clickstream_events_session_id ON analytics_clickstream_events(session_id);
