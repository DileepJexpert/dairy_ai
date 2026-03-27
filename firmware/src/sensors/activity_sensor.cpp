#include "activity_sensor.h"
#include "../config.h"
#include <Wire.h>

// =============================================================================
// MPU6050 Activity Sensor Implementation
// =============================================================================

// MPU6050 I2C address and registers
static const uint8_t MPU6050_ADDR        = 0x68;
static const uint8_t REG_PWR_MGMT_1      = 0x6B;
static const uint8_t REG_ACCEL_CONFIG     = 0x1C;
static const uint8_t REG_ACCEL_XOUT_H    = 0x3B;
static const uint8_t REG_WHO_AM_I        = 0x75;

// Conversion: raw 16-bit to g at +/- 2g range
static const float ACCEL_SCALE = 16384.0f;

// Activity scoring: magnitude of deviation from 1g (resting)
// These thresholds map real-world cattle movement to 0-100
static const float ACTIVITY_THRESHOLD_LOW  = 0.05f;  // Below this = resting (score 0)
static const float ACTIVITY_THRESHOLD_HIGH = 2.0f;   // Above this = max activity (score 100)

// Sampling for activity measurement
static const int   ACTIVITY_SAMPLES     = 50;
static const int   ACTIVITY_SAMPLE_MS   = 20;  // 50 Hz for 1 second window

void ActivitySensor::writeRegister(uint8_t reg, uint8_t value) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(reg);
    Wire.write(value);
    Wire.endTransmission(true);
}

int16_t ActivitySensor::readRegister16(uint8_t regHigh) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(regHigh);
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)MPU6050_ADDR, (uint8_t)2, (uint8_t)true);

    if (Wire.available() < 2) {
        return 0;
    }

    int16_t value = (Wire.read() << 8) | Wire.read();
    return value;
}

bool ActivitySensor::init() {
    Wire.begin();  // Default SDA=21, SCL=22 on ESP32

    // Check WHO_AM_I register to verify device presence
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(REG_WHO_AM_I);
    Wire.endTransmission(false);
    Wire.requestFrom((uint8_t)MPU6050_ADDR, (uint8_t)1, (uint8_t)true);

    if (Wire.available() < 1) {
        Serial.println("[ACCEL] ERROR: MPU6050 not found on I2C bus");
        _ready = false;
        return false;
    }

    uint8_t whoAmI = Wire.read();
    if (whoAmI != 0x68 && whoAmI != 0x72) {
        Serial.printf("[ACCEL] ERROR: Unexpected WHO_AM_I: 0x%02X\n", whoAmI);
        _ready = false;
        return false;
    }

    // Wake up the MPU6050 (clear sleep bit)
    writeRegister(REG_PWR_MGMT_1, 0x00);
    delay(100);

    // Set accelerometer range to +/- 2g (highest sensitivity)
    writeRegister(REG_ACCEL_CONFIG, 0x00);

    Serial.printf("[ACCEL] MPU6050 initialized (WHO_AM_I=0x%02X)\n", whoAmI);
    _ready = true;
    return true;
}

bool ActivitySensor::readRawAccel(float &ax, float &ay, float &az) {
    if (!_ready) return false;

    int16_t rawX = readRegister16(REG_ACCEL_XOUT_H);
    int16_t rawY = readRegister16(REG_ACCEL_XOUT_H + 2);
    int16_t rawZ = readRegister16(REG_ACCEL_XOUT_H + 4);

    ax = (float)rawX / ACCEL_SCALE;
    ay = (float)rawY / ACCEL_SCALE;
    az = (float)rawZ / ACCEL_SCALE;

    return true;
}

float ActivitySensor::read() {
    if (!_ready) {
        Serial.println("[ACCEL] Sensor not initialized");
        return -1.0f;
    }

    // Collect acceleration samples over the measurement window
    float totalDeviation = 0.0f;
    int validSamples = 0;

    for (int i = 0; i < ACTIVITY_SAMPLES; i++) {
        float ax, ay, az;
        if (readRawAccel(ax, ay, az)) {
            // Calculate magnitude of acceleration vector
            float magnitude = sqrtf(ax * ax + ay * ay + az * az);

            // Deviation from 1g (gravity at rest)
            float deviation = fabsf(magnitude - 1.0f);
            totalDeviation += deviation;
            validSamples++;
        }
        delay(ACTIVITY_SAMPLE_MS);
    }

    if (validSamples == 0) {
        Serial.println("[ACCEL] ERROR: No valid samples collected");
        return _lastReading;
    }

    float avgDeviation = totalDeviation / (float)validSamples;
    float activityScore = calculateActivityScore(avgDeviation);

    // Clamp to valid range
    if (activityScore < ACTIVITY_MIN) activityScore = ACTIVITY_MIN;
    if (activityScore > ACTIVITY_MAX) activityScore = ACTIVITY_MAX;

    float filtered = applyFilter(activityScore);
    _lastReading = filtered;

    Serial.printf("[ACCEL] AvgDev=%.3fg  Score=%.1f  Filtered=%.1f\n",
                  avgDeviation, activityScore, filtered);
    return filtered;
}

bool ActivitySensor::isReady() const {
    return _ready;
}

float ActivitySensor::getLastReading() const {
    return _lastReading;
}

float ActivitySensor::calculateActivityScore(float deviation) {
    if (deviation <= ACTIVITY_THRESHOLD_LOW) {
        return 0.0f;
    }
    if (deviation >= ACTIVITY_THRESHOLD_HIGH) {
        return 100.0f;
    }

    // Linear mapping between thresholds
    float normalized = (deviation - ACTIVITY_THRESHOLD_LOW) /
                       (ACTIVITY_THRESHOLD_HIGH - ACTIVITY_THRESHOLD_LOW);
    return normalized * 100.0f;
}

float ActivitySensor::applyFilter(float value) {
    _filterBuffer[_filterIndex] = value;
    _filterIndex = (_filterIndex + 1) % ACTIVITY_FILTER_SIZE;
    if (_filterCount < ACTIVITY_FILTER_SIZE) {
        _filterCount++;
    }

    float sum = 0.0f;
    for (uint8_t i = 0; i < _filterCount; i++) {
        sum += _filterBuffer[i];
    }
    return sum / (float)_filterCount;
}
