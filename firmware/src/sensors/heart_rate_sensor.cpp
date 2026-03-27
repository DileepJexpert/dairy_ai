#include "heart_rate_sensor.h"
#include "../config.h"

// =============================================================================
// Heart Rate Sensor Implementation — Peak Detection on Analog Input
// =============================================================================

// Sampling parameters
static const unsigned long SAMPLE_WINDOW_MS   = 5000;  // 5-second measurement window
static const unsigned long SAMPLE_INTERVAL_US = 2000;   // 500 Hz sampling rate
static const int           MIN_BEATS_REQUIRED = 2;      // Need at least 2 beats for BPM
static const int           PEAK_COOLDOWN_MS   = 300;    // Minimum interval between peaks

bool HeartRateSensor::init() {
    pinMode(HEART_RATE_PIN, INPUT);

    // Take a few calibration samples to set the baseline threshold
    long sum = 0;
    const int calibrationSamples = 100;
    for (int i = 0; i < calibrationSamples; i++) {
        sum += analogRead(HEART_RATE_PIN);
        delayMicroseconds(1000);
    }
    _threshold = (int)(sum / calibrationSamples) + 200;  // Offset above baseline

    Serial.printf("[HR] Initialized on ADC pin %d, threshold=%d\n",
                  HEART_RATE_PIN, _threshold);
    _ready = true;
    return true;
}

int HeartRateSensor::read() {
    if (!_ready) {
        Serial.println("[HR] Sensor not initialized");
        return -1;
    }

    int bpm = measureBPM();

    if (bpm < 0) {
        Serial.println("[HR] WARNING: No reliable pulse detected");
        return _lastReading;  // Return last known good reading
    }

    if (!isValid(bpm)) {
        Serial.printf("[HR] WARNING: Out-of-range reading: %d BPM\n", bpm);
        return _lastReading;
    }

    int filtered = applyFilter(bpm);
    _lastReading = filtered;

    Serial.printf("[HR] Raw=%d BPM  Filtered=%d BPM\n", bpm, filtered);
    return filtered;
}

bool HeartRateSensor::isReady() const {
    return _ready;
}

int HeartRateSensor::getLastReading() const {
    return _lastReading;
}

bool HeartRateSensor::isValid(int bpm) const {
    return (bpm >= HR_MIN_VALID_BPM && bpm <= HR_MAX_VALID_BPM);
}

int HeartRateSensor::applyFilter(int value) {
    _filterBuffer[_filterIndex] = value;
    _filterIndex = (_filterIndex + 1) % HR_FILTER_SIZE;
    if (_filterCount < HR_FILTER_SIZE) {
        _filterCount++;
    }

    int sum = 0;
    for (uint8_t i = 0; i < _filterCount; i++) {
        sum += _filterBuffer[i];
    }
    return sum / _filterCount;
}

int HeartRateSensor::measureBPM() {
    unsigned long startTime = millis();
    unsigned long lastPeakTime = 0;
    unsigned long intervalSum = 0;
    int peakCount = 0;
    bool aboveThreshold = false;
    int maxVal = 0;
    int minVal = 4095;

    // Sample for the full measurement window
    while ((millis() - startTime) < SAMPLE_WINDOW_MS) {
        int sample = analogRead(HEART_RATE_PIN);

        // Track signal range for adaptive thresholding
        if (sample > maxVal) maxVal = sample;
        if (sample < minVal) minVal = sample;

        // Detect rising edge crossing the threshold
        if (sample > _threshold && !aboveThreshold) {
            aboveThreshold = true;
            unsigned long now = millis();

            // Enforce cooldown to reject noise spikes
            if (lastPeakTime > 0 && (now - lastPeakTime) > PEAK_COOLDOWN_MS) {
                intervalSum += (now - lastPeakTime);
                peakCount++;
            }
            lastPeakTime = now;
        } else if (sample < (_threshold - 100)) {
            // Hysteresis: require signal to drop well below threshold before next peak
            aboveThreshold = false;
        }

        delayMicroseconds(SAMPLE_INTERVAL_US);
    }

    // Adapt threshold for next reading based on observed signal range
    int signalRange = maxVal - minVal;
    if (signalRange > 100) {
        _threshold = minVal + (signalRange * 6 / 10);  // 60% of range
    }

    // Calculate BPM from average inter-beat interval
    if (peakCount < MIN_BEATS_REQUIRED) {
        return -1;  // Not enough beats detected
    }

    unsigned long avgIntervalMs = intervalSum / peakCount;
    if (avgIntervalMs == 0) {
        return -1;
    }

    int bpm = (int)(60000UL / avgIntervalMs);
    return bpm;
}
