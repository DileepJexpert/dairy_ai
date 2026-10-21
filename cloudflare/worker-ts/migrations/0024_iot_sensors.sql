-- 0024_iot_sensors.sql: IoT Smart Collar Sensor Telemetry, Anomalies, and Device Commands Schema

CREATE TABLE IF NOT EXISTS sensor_readings (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    temperature REAL,
    heart_rate INTEGER,
    activity_level INTEGER,
    rumination_minutes REAL,
    battery_pct INTEGER,
    rssi INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sensor_anomalies (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    reading_id TEXT REFERENCES sensor_readings(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL CHECK (alert_type IN ('high_temperature', 'high_heart_rate', 'activity_drop', 'low_battery')),
    message TEXT NOT NULL,
    current_value REAL NOT NULL,
    threshold REAL NOT NULL,
    is_resolved INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS iot_device_commands (
    id TEXT PRIMARY KEY,
    cattle_id TEXT NOT NULL REFERENCES cattle(id) ON DELETE CASCADE,
    command TEXT NOT NULL CHECK (command IN ('SET_INTERVAL', 'REBOOT', 'OTA_UPDATE', 'STATUS_REQUEST')),
    param_int INTEGER,
    param_str TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'acknowledged', 'failed')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sensor_readings_cattle_time ON sensor_readings(cattle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_anomalies_cattle ON sensor_anomalies(cattle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iot_commands_pending ON iot_device_commands(cattle_id, status);
