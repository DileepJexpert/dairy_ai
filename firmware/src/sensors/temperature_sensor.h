#ifndef TEMPERATURE_SENSOR_H
#define TEMPERATURE_SENSOR_H

#include <Arduino.h>

// =============================================================================
// DS18B20 Temperature Sensor
// =============================================================================
// Reads body temperature via a waterproof DS18B20 probe attached to the cattle.
// Uses a moving average filter to smooth noisy readings.
// Valid cattle body temperature: 25-45 deg C.
// =============================================================================

class TemperatureSensor {
public:
    /// Initialize the sensor on the configured pin.
    /// Returns true if at least one DS18B20 device is detected on the bus.
    bool init();

    /// Take a raw reading, apply validation and filtering.
    /// Returns the filtered temperature in Celsius, or -1.0 if no valid reading.
    float read();

    /// Check whether the sensor was successfully initialized.
    bool isReady() const;

    /// Return the last valid filtered temperature without triggering a new read.
    float getLastReading() const;

private:
    bool     _ready = false;
    float    _lastReading = -1.0f;
    float    _filterBuffer[5] = {0};
    uint8_t  _filterIndex = 0;
    uint8_t  _filterCount = 0;

    /// Validate that a raw temperature is within the expected cattle range.
    bool isValid(float tempC) const;

    /// Push a value into the moving-average buffer and return the average.
    float applyFilter(float value);
};

#endif // TEMPERATURE_SENSOR_H
