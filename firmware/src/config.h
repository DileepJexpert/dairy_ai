#ifndef CONFIG_H
#define CONFIG_H

// =============================================================================
// DairyAI Cattle Monitor — Configuration
// =============================================================================
// Each device must have a unique CATTLE_ID matching the backend database.
// Update WiFi and MQTT credentials before flashing.
// =============================================================================

// --- WiFi Configuration ---
#define WIFI_SSID           "DairyAI_Farm"
#define WIFI_PASSWORD        "changeme_wifi_password"
#define WIFI_CONNECT_TIMEOUT_MS  15000
#define WIFI_RETRY_DELAY_MS      5000
#define WIFI_MAX_RETRIES         5

// --- MQTT Configuration ---
#define MQTT_BROKER_HOST    "mqtt.dairyai.in"
#define MQTT_BROKER_PORT    1883
#define MQTT_USERNAME       ""
#define MQTT_PASSWORD       ""
#define MQTT_CLIENT_PREFIX  "dairyai_"
#define MQTT_KEEPALIVE_SEC  60
#define MQTT_RECONNECT_DELAY_MS  5000
#define MQTT_MAX_RETRIES    10
#define MQTT_BUFFER_SIZE    512

// --- Device Identity ---
#define CATTLE_ID           "CATTLE_001"
#define FIRMWARE_VERSION    "1.0.0"

// --- Sensor Pins ---
#define TEMP_SENSOR_PIN     4       // DS18B20 data pin (GPIO4)
#define HEART_RATE_PIN      34      // Pulse sensor analog input (ADC1_CH6)
#define BATTERY_ADC_PIN     35      // Battery voltage divider (ADC1_CH7)
#define STATUS_LED_PIN      2       // Onboard LED (GPIO2)

// MPU6050 uses default I2C: SDA=GPIO21, SCL=GPIO22

// --- Timing Configuration ---
#define SENSOR_READ_INTERVAL_SEC    30
#define DEEP_SLEEP_DURATION_SEC     0       // 0 = no deep sleep (continuous mode)
#define SENSOR_WARMUP_DELAY_MS      500
#define WATCHDOG_TIMEOUT_SEC        120

// --- Sensor Validation Ranges ---
#define TEMP_MIN_VALID_C    25.0f
#define TEMP_MAX_VALID_C    45.0f
#define HR_MIN_VALID_BPM    30
#define HR_MAX_VALID_BPM    120
#define ACTIVITY_MIN        0.0f
#define ACTIVITY_MAX        100.0f

// --- Filter Settings ---
#define TEMP_FILTER_SIZE    5
#define HR_FILTER_SIZE      5
#define ACTIVITY_FILTER_SIZE 5

// --- Battery Configuration ---
#define BATTERY_VOLTAGE_MIN     3.0f    // 0% for LiPo
#define BATTERY_VOLTAGE_MAX     4.2f    // 100% for LiPo
#define BATTERY_LOW_THRESHOLD   15      // Low battery warning at 15%
#define BATTERY_ADC_DIVIDER     2.0f    // Voltage divider ratio (R1=R2)
#define BATTERY_ADC_REFERENCE   3.3f    // ESP32 ADC reference voltage
#define BATTERY_ADC_RESOLUTION  4095.0f // 12-bit ADC

// --- MQTT Topics (constructed at runtime with CATTLE_ID) ---
#define MQTT_TOPIC_PREFIX       "dairy/cattle/"
#define MQTT_TOPIC_SENSORS      "/sensors"
#define MQTT_TOPIC_COMMANDS     "/commands"
#define MQTT_TOPIC_STATUS       "/status"

#endif // CONFIG_H
