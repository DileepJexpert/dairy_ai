#ifndef MQTT_HANDLER_H
#define MQTT_HANDLER_H

#include <Arduino.h>
#include <PubSubClient.h>
#include <WiFiClient.h>

// =============================================================================
// MQTT Handler — Publish Sensor Data and Receive Commands
// =============================================================================
// Manages the MQTT connection lifecycle, publishes structured JSON sensor
// payloads, and subscribes to a per-device command topic for remote control
// (interval changes, reboot, OTA trigger, etc.).
// =============================================================================

/// Command types that can be received over MQTT
enum class MqttCommand {
    NONE,
    SET_INTERVAL,
    REBOOT,
    OTA_UPDATE,
    STATUS_REQUEST
};

/// Parsed command with optional integer parameter
struct CommandMessage {
    MqttCommand command;
    int         paramInt;
    char        paramStr[64];
};

class MqttHandler {
public:
    /// Initialize MQTT client with broker settings from config.
    void init();

    /// Attempt to connect (or reconnect) to the broker.
    /// Returns true if connected.
    bool connect();

    /// Call in loop() to process incoming messages and maintain connection.
    void loop();

    /// Check if connected to the broker.
    bool isConnected() const;

    /// Publish a sensor reading payload.
    /// Returns true if the message was successfully queued.
    bool publishSensorData(float temperature, int heartRate,
                           float activityLevel, int batteryPct);

    /// Publish a status/heartbeat message.
    bool publishStatus(const char* status);

    /// Check if a new command has been received.
    bool hasCommand() const;

    /// Consume the pending command (resets the flag).
    CommandMessage consumeCommand();

private:
    WiFiClient    _wifiClient;
    PubSubClient  _mqttClient;
    bool          _initialized = false;
    unsigned long _lastReconnectAttempt = 0;
    int           _reconnectCount = 0;

    // Topics built from CATTLE_ID at init time
    char _topicSensors[64];
    char _topicCommands[64];
    char _topicStatus[64];
    char _clientId[32];

    // Pending command from subscription
    volatile bool _commandPending = false;
    CommandMessage _pendingCommand;

    /// Static callback trampoline for PubSubClient
    static void mqttCallbackStatic(char* topic, byte* payload, unsigned int length);

    /// Instance callback for processing incoming messages
    void handleMessage(char* topic, byte* payload, unsigned int length);

    /// Parse a JSON command payload into a CommandMessage
    void parseCommand(const char* json, unsigned int length);

    /// Build topic strings from the cattle ID
    void buildTopics();
};

// Global instance (PubSubClient requires a static callback)
extern MqttHandler mqttHandler;

#endif // MQTT_HANDLER_H
