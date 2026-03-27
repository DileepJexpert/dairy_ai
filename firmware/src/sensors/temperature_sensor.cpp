#include "temperature_sensor.h"
#include "../config.h"
#include <OneWire.h>
#include <DallasTemperature.h>

// =============================================================================
// DS18B20 Temperature Sensor Implementation
// =============================================================================

static OneWire           oneWire(TEMP_SENSOR_PIN);
static DallasTemperature dallas(&oneWire);

bool TemperatureSensor::init() {
    dallas.begin();

    int deviceCount = dallas.getDeviceCount();
    if (deviceCount == 0) {
        Serial.println("[TEMP] ERROR: No DS18B20 devices found");
        _ready = false;
        return false;
    }

    // Use 12-bit resolution for best accuracy (750 ms conversion time)
    dallas.setResolution(12);
    dallas.setWaitForConversion(true);

    Serial.printf("[TEMP] Initialized — %d device(s) found on GPIO%d\n",
                  deviceCount, TEMP_SENSOR_PIN);
    _ready = true;
    return true;
}

float TemperatureSensor::read() {
    if (!_ready) {
        Serial.println("[TEMP] Sensor not initialized");
        return -1.0f;
    }

    dallas.requestTemperatures();
    float rawTemp = dallas.getTempCByIndex(0);

    // DallasTemperature returns DEVICE_DISCONNECTED_C (-127) on failure
    if (rawTemp == DEVICE_DISCONNECTED_C) {
        Serial.println("[TEMP] ERROR: Sensor disconnected or read failure");
        return _lastReading;  // Return last known good reading
    }

    if (!isValid(rawTemp)) {
        Serial.printf("[TEMP] WARNING: Out-of-range reading: %.2f°C\n", rawTemp);
        return _lastReading;  // Reject outlier, keep last good value
    }

    float filtered = applyFilter(rawTemp);
    _lastReading = filtered;

    Serial.printf("[TEMP] Raw=%.2f°C  Filtered=%.2f°C\n", rawTemp, filtered);
    return filtered;
}

bool TemperatureSensor::isReady() const {
    return _ready;
}

float TemperatureSensor::getLastReading() const {
    return _lastReading;
}

bool TemperatureSensor::isValid(float tempC) const {
    return (tempC >= TEMP_MIN_VALID_C && tempC <= TEMP_MAX_VALID_C);
}

float TemperatureSensor::applyFilter(float value) {
    _filterBuffer[_filterIndex] = value;
    _filterIndex = (_filterIndex + 1) % TEMP_FILTER_SIZE;
    if (_filterCount < TEMP_FILTER_SIZE) {
        _filterCount++;
    }

    float sum = 0.0f;
    for (uint8_t i = 0; i < _filterCount; i++) {
        sum += _filterBuffer[i];
    }
    return sum / (float)_filterCount;
}
