#include "mqtt_handler.h"
#include "../config.h"
#include <ArduinoJson.h>

// =============================================================================
// MQTT Handler Implementation
// =============================================================================

// Global instance for the static callback trampoline
MqttHandler mqttHandler;

void MqttHandler::init() {
    buildTopics();

    _mqttClient.setClient(_wifiClient);
    _mqttClient.setServer(MQTT_BROKER_HOST, MQTT_BROKER_PORT);
    _mqttClient.setBufferSize(MQTT_BUFFER_SIZE);
    _mqttClient.setKeepAlive(MQTT_KEEPALIVE_SEC);
    _mqttClient.setCallback(MqttHandler::mqttCallbackStatic);

    _pendingCommand.command = MqttCommand::NONE;
    _commandPending = false;
    _initialized = true;

    Serial.printf("[MQTT] Initialized — broker=%s:%d  client=%s\n",
                  MQTT_BROKER_HOST, MQTT_BROKER_PORT, _clientId);
    Serial.printf("[MQTT] Publish topic: %s\n", _topicSensors);
    Serial.printf("[MQTT] Command topic: %s\n", _topicCommands);
}

void MqttHandler::buildTopics() {
    snprintf(_topicSensors, sizeof(_topicSensors),
             "%s%s%s", MQTT_TOPIC_PREFIX, CATTLE_ID, MQTT_TOPIC_SENSORS);
    snprintf(_topicCommands, sizeof(_topicCommands),
             "%s%s%s", MQTT_TOPIC_PREFIX, CATTLE_ID, MQTT_TOPIC_COMMANDS);
    snprintf(_topicStatus, sizeof(_topicStatus),
             "%s%s%s", MQTT_TOPIC_PREFIX, CATTLE_ID, MQTT_TOPIC_STATUS);
    snprintf(_clientId, sizeof(_clientId),
             "%s%s", MQTT_CLIENT_PREFIX, CATTLE_ID);
}

bool MqttHandler::connect() {
    if (!_initialized) {
        Serial.println("[MQTT] ERROR: Not initialized");
        return false;
    }

    if (_mqttClient.connected()) {
        return true;
    }

    // Rate-limit reconnection attempts
    unsigned long now = millis();
    if (now - _lastReconnectAttempt < MQTT_RECONNECT_DELAY_MS) {
        return false;
    }
    _lastReconnectAttempt = now;
    _reconnectCount++;

    Serial.printf("[MQTT] Connecting (attempt %d/%d)...\n",
                  _reconnectCount, MQTT_MAX_RETRIES);

    // Build a last-will message so the backend knows if we go offline
    bool connected = false;
    if (strlen(MQTT_USERNAME) > 0) {
        connected = _mqttClient.connect(_clientId, MQTT_USERNAME, MQTT_PASSWORD,
                                         _topicStatus, 1, true, "{\"online\":false}");
    } else {
        connected = _mqttClient.connect(_clientId,
                                         _topicStatus, 1, true, "{\"online\":false}");
    }

    if (connected) {
        Serial.println("[MQTT] Connected to broker");
        _reconnectCount = 0;

        // Subscribe to command topic
        if (_mqttClient.subscribe(_topicCommands)) {
            Serial.printf("[MQTT] Subscribed to: %s\n", _topicCommands);
        } else {
            Serial.println("[MQTT] WARNING: Failed to subscribe to commands");
        }

        // Publish online status
        publishStatus("online");
        return true;
    }

    int state = _mqttClient.state();
    Serial.printf("[MQTT] Connection failed, rc=%d\n", state);

    if (_reconnectCount >= MQTT_MAX_RETRIES) {
        Serial.println("[MQTT] Max retries reached — will keep trying");
        _reconnectCount = 0;  // Reset counter, keep retrying
    }

    return false;
}

void MqttHandler::loop() {
    if (!_initialized) return;

    if (!_mqttClient.connected()) {
        connect();
    }

    // Process incoming MQTT messages
    _mqttClient.loop();
}

bool MqttHandler::isConnected() const {
    return _mqttClient.connected();
}

bool MqttHandler::publishSensorData(float temperature, int heartRate,
                                     float activityLevel, int batteryPct) {
    if (!_mqttClient.connected()) {
        Serial.println("[MQTT] Cannot publish — not connected");
        return false;
    }

    // Build JSON payload using ArduinoJson
    StaticJsonDocument<256> doc;
    doc["cattle_id"]      = CATTLE_ID;
    doc["temperature"]    = serialized(String(temperature, 2));
    doc["heart_rate"]     = heartRate;
    doc["activity_level"] = serialized(String(activityLevel, 1));
    doc["battery_pct"]    = batteryPct;
    doc["timestamp"]      = (long)millis();  // Relative uptime; server uses its own clock
    doc["firmware"]       = FIRMWARE_VERSION;

    char buffer[MQTT_BUFFER_SIZE];
    size_t len = serializeJson(doc, buffer, sizeof(buffer));

    bool success = _mqttClient.publish(_topicSensors, buffer, false);
    if (success) {
        Serial.printf("[MQTT] Published %d bytes to %s\n", (int)len, _topicSensors);
    } else {
        Serial.println("[MQTT] ERROR: Publish failed");
    }

    return success;
}

bool MqttHandler::publishStatus(const char* status) {
    if (!_mqttClient.connected()) return false;

    StaticJsonDocument<128> doc;
    doc["online"]   = (strcmp(status, "online") == 0);
    doc["status"]   = status;
    doc["firmware"]  = FIRMWARE_VERSION;
    doc["uptime_ms"] = millis();

    char buffer[128];
    serializeJson(doc, buffer, sizeof(buffer));

    return _mqttClient.publish(_topicStatus, buffer, true);  // Retained message
}

bool MqttHandler::hasCommand() const {
    return _commandPending;
}

CommandMessage MqttHandler::consumeCommand() {
    CommandMessage cmd = _pendingCommand;
    _commandPending = false;
    _pendingCommand.command = MqttCommand::NONE;
    return cmd;
}

// --- Static callback trampoline ---
void MqttHandler::mqttCallbackStatic(char* topic, byte* payload, unsigned int length) {
    mqttHandler.handleMessage(topic, payload, length);
}

void MqttHandler::handleMessage(char* topic, byte* payload, unsigned int length) {
    Serial.printf("[MQTT] Received %d bytes on topic: %s\n", length, topic);

    // Only process messages on our command topic
    if (strcmp(topic, _topicCommands) == 0) {
        parseCommand((const char*)payload, length);
    }
}

void MqttHandler::parseCommand(const char* json, unsigned int length) {
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, json, length);

    if (error) {
        Serial.printf("[MQTT] Command parse error: %s\n", error.c_str());
        return;
    }

    const char* cmd = doc["command"] | "";
    Serial.printf("[MQTT] Command received: %s\n", cmd);

    if (strcmp(cmd, "set_interval") == 0) {
        _pendingCommand.command = MqttCommand::SET_INTERVAL;
        _pendingCommand.paramInt = doc["value"] | SENSOR_READ_INTERVAL_SEC;
        Serial.printf("[MQTT] Set interval to %d seconds\n", _pendingCommand.paramInt);
    } else if (strcmp(cmd, "reboot") == 0) {
        _pendingCommand.command = MqttCommand::REBOOT;
        Serial.println("[MQTT] Reboot command received");
    } else if (strcmp(cmd, "ota_update") == 0) {
        _pendingCommand.command = MqttCommand::OTA_UPDATE;
        const char* url = doc["url"] | "";
        strncpy(_pendingCommand.paramStr, url, sizeof(_pendingCommand.paramStr) - 1);
        _pendingCommand.paramStr[sizeof(_pendingCommand.paramStr) - 1] = '\0';
        Serial.printf("[MQTT] OTA update from: %s\n", _pendingCommand.paramStr);
    } else if (strcmp(cmd, "status") == 0) {
        _pendingCommand.command = MqttCommand::STATUS_REQUEST;
        Serial.println("[MQTT] Status request received");
    } else {
        Serial.printf("[MQTT] Unknown command: %s\n", cmd);
        return;
    }

    _commandPending = true;
}
