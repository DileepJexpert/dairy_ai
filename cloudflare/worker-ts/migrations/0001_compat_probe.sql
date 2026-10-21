-- Isolated compatibility proof only. No customer or commerce data belongs here.
CREATE TABLE IF NOT EXISTS compat_probe (
    probe_key TEXT PRIMARY KEY NOT NULL,
    probe_value TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
