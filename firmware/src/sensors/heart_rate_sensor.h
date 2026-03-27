#ifndef HEART_RATE_SENSOR_H
#define HEART_RATE_SENSOR_H

#include <Arduino.h>

// =============================================================================
// Pulse / Heart Rate Sensor (Analog)
// =============================================================================
// Reads an analog pulse sensor to estimate cattle heart rate in BPM.
// Uses peak detection to identify heartbeats, then calculates BPM from
// the inter-beat interval. A smoothing filter reduces noise.
// Valid cattle heart rate: 30-120 BPM.
// =============================================================================

class HeartRateSensor {
public:
    /// Initialize the analog pin for reading.
    bool init();

    /// Sample the sensor over a measurement window and return BPM.
    /// This is a blocking call (~5 seconds) to capture enough beats.
    /// Returns filtered BPM, or -1 if no reliable signal detected.
    int read();

    /// Check initialization state.
    bool isReady() const;

    /// Get the last valid BPM without triggering a new measurement.
    int getLastReading() const;

private:
    bool    _ready = false;
    int     _lastReading = -1;
    int     _filterBuffer[5] = {0};
    uint8_t _filterIndex = 0;
    uint8_t _filterCount = 0;

    /// Threshold for peak detection (auto-calibrated).
    int _threshold = 2048;

    /// Validate that a BPM reading is within the expected cattle range.
    bool isValid(int bpm) const;

    /// Push a value into the smoothing buffer and return the average.
    int applyFilter(int value);

    /// Measure BPM using peak detection over a sampling window.
    int measureBPM();
};

#endif // HEART_RATE_SENSOR_H
