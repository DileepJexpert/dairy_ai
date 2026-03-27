// =============================================================================
// DairyAI Cattle Monitor — ESP32 Firmware
// =============================================================================
// Main entry point for the IoT cattle health monitoring node.
//
// This firmware reads temperature, heart rate, and activity sensors attached
// to dairy cattle, then publishes the data over MQTT to the DairyAI backend.
// It supports remote commands (interval change, reboot, OTA) and can enter
// deep sleep between readings to conserve battery.
//
// Hardware:
//   - ESP32 DevKit
//   - DS18B20 waterproof temperature probe (GPIO4)
//   - Analog pulse sensor (GPIO34)
//   - MPU6050 accelerometer (I2C: SDA=21, SCL=22)
//   - LiPo battery with voltage divider (GPIO35)
//   - Status LED (GPIO2)
// =============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <esp_task_wdt.h>

#include "config.h"
#include "sensors/temperature_sensor.h"
#include "sensors/heart_rate_sensor.h"
#include "sensors/activity_sensor.h"
#include "mqtt/mqtt_handler.h"
#include "utils/battery.h"

// -----------------------------------------------------------------------------
// Globals
// -----------------------------------------------------------------------------
static TemperatureSensor tempSensor;
static HeartRateSensor   hrSensor;
static ActivitySensor    activitySensor;

static unsigned long lastReadTime      = 0;
static int           readIntervalSec   = SENSOR_READ_INTERVAL_SEC;
static bool          sensorsOk         = false;
static int           consecutiveErrors = 0;

// LED blink patterns
static const int LED_BLINK_WIFI     = 100;  // Fast blink while connecting WiFi
static const int LED_BLINK_MQTT     = 300;  // Medium blink while connecting MQTT
static const int LED_ON_OK          = 0;    // Solid on when all good

// Max consecutive read errors before reboot
static const int MAX_CONSECUTIVE_ERRORS = 10;

// RTC memory survives deep sleep — track boot count for diagnostics
RTC_DATA_ATTR int bootCount = 0;

// -----------------------------------------------------------------------------
// Forward declarations
// -----------------------------------------------------------------------------
void setupWiFi();
void setupSensors();
void readAndPublish();
void handleCommands();
void enterDeepSleep();
void blinkLED(int intervalMs, int count);
void setLED(bool on);

// =============================================================================
// setup()
// =============================================================================
void setup() {
    Serial.begin(115200);
    delay(500);

    bootCount++;
    Serial.println("\n========================================");
    Serial.println("  DairyAI Cattle Monitor");
    Serial.printf("  Firmware: %s\n", FIRMWARE_VERSION);
    Serial.printf("  Cattle ID: %s\n", CATTLE_ID);
    Serial.printf("  Boot count: %d\n", bootCount);
    Serial.println("========================================\n");

    // Initialize status LED
    pinMode(STATUS_LED_PIN, OUTPUT);
    setLED(true);

    // Enable hardware watchdog timer
    esp_task_wdt_init(WATCHDOG_TIMEOUT_SEC, true);  // Panic (reboot) on timeout
    esp_task_wdt_add(NULL);  // Add current task to WDT

    // Connect to WiFi
    setupWiFi();

    // Initialize MQTT
    mqttHandler.init();
    mqttHandler.connect();

    // Initialize battery monitor
    Battery::init();
    Battery::printStatus();

    // Initialize sensors
    setupSensors();

    // OTA update placeholder
    // TODO: Implement ArduinoOTA or HTTP OTA when backend endpoint is ready
    // ArduinoOTA.setHostname(CATTLE_ID);
    // ArduinoOTA.begin();

    Serial.println("\n[MAIN] Setup complete — entering main loop\n");
}

// =============================================================================
// loop()
// =============================================================================
void loop() {
    // Feed the watchdog
    esp_task_wdt_reset();

    // Maintain MQTT connection
    mqttHandler.loop();

    // Check for incoming MQTT commands
    handleCommands();

    // OTA update handler placeholder
    // ArduinoOTA.handle();

    // Read sensors and publish at the configured interval
    unsigned long now = millis();
    unsigned long intervalMs = (unsigned long)readIntervalSec * 1000UL;

    if (now - lastReadTime >= intervalMs) {
        lastReadTime = now;
        readAndPublish();

        // Enter deep sleep if configured (otherwise stay in continuous loop)
        if (DEEP_SLEEP_DURATION_SEC > 0) {
            enterDeepSleep();
        }
    }

    // Brief yield to allow WiFi/MQTT background processing
    delay(10);
}

// =============================================================================
// WiFi Setup
// =============================================================================
void setupWiFi() {
    Serial.printf("[WIFI] Connecting to %s", WIFI_SSID);

    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int retries = 0;
    unsigned long startAttempt = millis();

    while (WiFi.status() != WL_CONNECTED) {
        blinkLED(LED_BLINK_WIFI, 1);
        Serial.print(".");

        if (millis() - startAttempt > WIFI_CONNECT_TIMEOUT_MS) {
            retries++;
            if (retries >= WIFI_MAX_RETRIES) {
                Serial.println("\n[WIFI] FATAL: Cannot connect — rebooting");
                ESP.restart();
            }
            Serial.printf("\n[WIFI] Timeout — retry %d/%d\n", retries, WIFI_MAX_RETRIES);
            WiFi.disconnect();
            delay(WIFI_RETRY_DELAY_MS);
            WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
            startAttempt = millis();
        }
    }

    Serial.println();
    Serial.printf("[WIFI] Connected — IP: %s  RSSI: %d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
}

// =============================================================================
// Sensor Initialization
// =============================================================================
void setupSensors() {
    Serial.println("[MAIN] Initializing sensors...");

    delay(SENSOR_WARMUP_DELAY_MS);

    bool tempOk     = tempSensor.init();
    bool hrOk       = hrSensor.init();
    bool activityOk = activitySensor.init();

    sensorsOk = tempOk && hrOk && activityOk;

    Serial.printf("[MAIN] Sensor status — Temp:%s  HR:%s  Activity:%s\n",
                  tempOk ? "OK" : "FAIL",
                  hrOk ? "OK" : "FAIL",
                  activityOk ? "OK" : "FAIL");

    if (!sensorsOk) {
        Serial.println("[MAIN] WARNING: Not all sensors initialized — will send partial data");
    }
}

// =============================================================================
// Read Sensors and Publish via MQTT
// =============================================================================
void readAndPublish() {
    Serial.println("\n--- Sensor Read Cycle ---");

    // Read each sensor (gracefully handles failures)
    float temperature   = tempSensor.isReady()     ? tempSensor.read()     : -1.0f;
    int   heartRate     = hrSensor.isReady()        ? hrSensor.read()       : -1;
    float activityLevel = activitySensor.isReady()  ? activitySensor.read() : -1.0f;
    int   batteryPct    = Battery::readPercentage();

    // Log battery warnings
    if (Battery::isLow()) {
        Serial.println("[MAIN] WARNING: Battery low!");
    }

    // Check WiFi health
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[MAIN] WiFi disconnected — attempting reconnect");
        setupWiFi();
    }

    // Publish to MQTT
    bool published = mqttHandler.publishSensorData(
        temperature, heartRate, activityLevel, batteryPct
    );

    if (published) {
        consecutiveErrors = 0;
        setLED(true);  // Solid LED = healthy
        Serial.println("[MAIN] Data published successfully");
    } else {
        consecutiveErrors++;
        blinkLED(LED_BLINK_MQTT, 3);  // Blink to indicate error
        Serial.printf("[MAIN] Publish failed (%d consecutive errors)\n", consecutiveErrors);

        if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
            Serial.println("[MAIN] Too many errors — rebooting");
            ESP.restart();
        }
    }

    Battery::printStatus();
    Serial.println("--- End Read Cycle ---\n");
}

// =============================================================================
// Handle MQTT Commands
// =============================================================================
void handleCommands() {
    if (!mqttHandler.hasCommand()) return;

    CommandMessage cmd = mqttHandler.consumeCommand();

    switch (cmd.command) {
        case MqttCommand::SET_INTERVAL:
            if (cmd.paramInt >= 5 && cmd.paramInt <= 3600) {
                readIntervalSec = cmd.paramInt;
                Serial.printf("[CMD] Read interval changed to %d seconds\n", readIntervalSec);
            } else {
                Serial.printf("[CMD] Invalid interval: %d (must be 5-3600)\n", cmd.paramInt);
            }
            break;

        case MqttCommand::REBOOT:
            Serial.println("[CMD] Reboot requested — restarting in 2 seconds");
            mqttHandler.publishStatus("rebooting");
            delay(2000);
            ESP.restart();
            break;

        case MqttCommand::OTA_UPDATE:
            Serial.printf("[CMD] OTA update requested from: %s\n", cmd.paramStr);
            mqttHandler.publishStatus("ota_updating");
            // TODO: Implement HTTP OTA update
            // httpUpdate.update(_wifiClient, cmd.paramStr);
            Serial.println("[CMD] OTA not yet implemented — ignoring");
            break;

        case MqttCommand::STATUS_REQUEST:
            Serial.println("[CMD] Status request — publishing status");
            mqttHandler.publishStatus("online");
            Battery::printStatus();
            break;

        case MqttCommand::NONE:
            break;
    }
}

// =============================================================================
// Deep Sleep
// =============================================================================
void enterDeepSleep() {
    Serial.printf("[MAIN] Entering deep sleep for %d seconds\n", DEEP_SLEEP_DURATION_SEC);

    // Publish offline status before sleeping
    mqttHandler.publishStatus("sleeping");
    delay(100);  // Allow MQTT message to be sent

    // Configure wake-up timer
    esp_sleep_enable_timer_wakeup((uint64_t)DEEP_SLEEP_DURATION_SEC * 1000000ULL);

    // Turn off LED
    setLED(false);

    Serial.flush();
    esp_deep_sleep_start();
    // Execution stops here — device resets on wake-up, re-entering setup()
}

// =============================================================================
// LED Helpers
// =============================================================================
void setLED(bool on) {
    digitalWrite(STATUS_LED_PIN, on ? HIGH : LOW);
}

void blinkLED(int intervalMs, int count) {
    for (int i = 0; i < count; i++) {
        setLED(true);
        delay(intervalMs);
        setLED(false);
        delay(intervalMs);
    }
}
