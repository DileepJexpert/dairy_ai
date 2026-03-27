#ifndef ACTIVITY_SENSOR_H
#define ACTIVITY_SENSOR_H

#include <Arduino.h>

// =============================================================================
// MPU6050 Accelerometer — Activity Level Sensor
// =============================================================================
// Reads 3-axis acceleration from an MPU6050 over I2C to estimate cattle
// movement / activity level on a 0-100 scale. Uses magnitude of acceleration
// deviation from 1g (resting) sampled over a window, then maps to a
// normalized activity score. A rolling average smooths the output.
// =============================================================================

class ActivitySensor {
public:
    /// Initialize I2C communication with the MPU6050.
    /// Returns true if the device responds on the bus.
    bool init();

    /// Sample acceleration over a short window and return activity level (0-100).
    /// Returns -1.0 on failure.
    float read();

    /// Check initialization state.
    bool isReady() const;

    /// Get last valid activity level without triggering a new read.
    float getLastReading() const;

    /// Read raw acceleration values (in g) for diagnostics.
    bool readRawAccel(float &ax, float &ay, float &az);

private:
    bool    _ready = false;
    float   _lastReading = -1.0f;
    float   _filterBuffer[5] = {0};
    uint8_t _filterIndex = 0;
    uint8_t _filterCount = 0;

    /// Write a byte to an MPU6050 register.
    void writeRegister(uint8_t reg, uint8_t value);

    /// Read a 16-bit signed value from two consecutive registers.
    int16_t readRegister16(uint8_t regHigh);

    /// Push a value into the rolling-average buffer and return the average.
    float applyFilter(float value);

    /// Convert acceleration magnitude deviation into a 0-100 activity score.
    float calculateActivityScore(float magnitude);
};

#endif // ACTIVITY_SENSOR_H
