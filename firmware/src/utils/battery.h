#ifndef BATTERY_H
#define BATTERY_H

#include <Arduino.h>
#include "../config.h"

// =============================================================================
// Battery Level Monitor
// =============================================================================
// Reads battery voltage through a resistor divider connected to an ADC pin.
// Converts the voltage to a percentage for LiPo cells (3.0V–4.2V).
// Provides a low-battery warning flag.
//
// Hardware: Battery+ → [R1] → ADC_PIN → [R2] → GND
//           Voltage at ADC = Vbat * R2 / (R1 + R2)
//           With equal resistors: ADC = Vbat / 2
// =============================================================================

namespace Battery {

    /// Initialize the ADC pin for battery reading.
    inline void init() {
        pinMode(BATTERY_ADC_PIN, INPUT);
        // Use 11dB attenuation for full 0-3.3V range on ESP32
        analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);
        Serial.printf("[BATT] Initialized on ADC pin %d\n", BATTERY_ADC_PIN);
    }

    /// Read the raw battery voltage in volts (after divider compensation).
    inline float readVoltage() {
        // Average multiple samples to reduce ADC noise
        const int samples = 16;
        long sum = 0;
        for (int i = 0; i < samples; i++) {
            sum += analogRead(BATTERY_ADC_PIN);
            delayMicroseconds(100);
        }
        float adcAvg = (float)sum / (float)samples;

        // Convert ADC reading to voltage at the pin
        float pinVoltage = (adcAvg / BATTERY_ADC_RESOLUTION) * BATTERY_ADC_REFERENCE;

        // Compensate for the voltage divider to get actual battery voltage
        float batteryVoltage = pinVoltage * BATTERY_ADC_DIVIDER;

        return batteryVoltage;
    }

    /// Convert battery voltage to a percentage (0-100).
    /// Uses linear mapping between BATTERY_VOLTAGE_MIN and BATTERY_VOLTAGE_MAX.
    inline int readPercentage() {
        float voltage = readVoltage();

        if (voltage <= BATTERY_VOLTAGE_MIN) {
            return 0;
        }
        if (voltage >= BATTERY_VOLTAGE_MAX) {
            return 100;
        }

        float pct = (voltage - BATTERY_VOLTAGE_MIN) /
                     (BATTERY_VOLTAGE_MAX - BATTERY_VOLTAGE_MIN) * 100.0f;
        return (int)pct;
    }

    /// Check whether the battery is below the low-battery warning threshold.
    inline bool isLow() {
        return readPercentage() < BATTERY_LOW_THRESHOLD;
    }

    /// Print battery diagnostics to serial.
    inline void printStatus() {
        float voltage = readVoltage();
        int pct = readPercentage();
        Serial.printf("[BATT] Voltage=%.2fV  Level=%d%%  Low=%s\n",
                      voltage, pct, isLow() ? "YES" : "no");
    }

} // namespace Battery

#endif // BATTERY_H
