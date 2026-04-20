#include <ArduinoJson.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <MFRC522.h>
#include <PubSubClient.h>
#include <RTClib.h>
#include <SPI.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <esp_now.h>
#include <esp_wifi.h>

// ===== 1. SETTINGS ===
const char *ssid = "Alo";
const char *password = "11111114";
String authorizedUID = "A3 6F 77 22";
float tempThreshold = 28.0;
const char *mqtt_server = "tf897ef8.ala.dedicated.aws.emqxcloud.com";
const int mqtt_port = 8883;
const char *mqtt_user = "ESP32";
const char *mqtt_password = "123";
const char *topic_root = "home/main";
constexpr uint8_t WIFI_CHAN = 1;

const char *emqx_ca_cert = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)EOF";

// ── MAC ADDRESSES ──
uint8_t garageAddress[] = {0x24, 0x0A, 0xC4, 0x2E, 0x53, 0x14};
uint8_t gardenAddress[] = {0xAC, 0x15, 0x18, 0xE4, 0xDF, 0xA8};

// ── ESP-NOW Structured Message ──
typedef struct struct_message {
  char device[16];
  char command[16];
  float value;
} struct_message;

struct_message outgoingMsg;
struct_message incomingMsg;
esp_now_peer_info_t garagePeerInfo;
esp_now_peer_info_t gardenPeerInfo;

// ===== 2. PIN DEFINITIONS =====
#define TV_LED 16
#define WASH_LED 17
#define LIGHT1_LED 26
#define LIGHT2_LED 25
#define LIGHT3_LED 33
#define RGB_R 2
#define RGB_G 12
#define RGB_B 15
#define REAL_FAN_PIN 13
#define SERVO_PIN 14
#define PIR_PIN 34
#define LDR_PIN 35
#define DHTPIN 4
#define BUZZER_PIN 32
#define SS_PIN 5
#define RST_PIN 27
#define SCK_PIN 18
#define MISO_PIN 19
#define MOSI_PIN 23

#define DHTTYPE DHT11

// ===== 3. OBJECTS =====
DHT dht(DHTPIN, DHTTYPE);
RTC_DS3231 rtc;
LiquidCrystal_I2C lcd(0x27, 16, 2);
MFRC522 rfid(SS_PIN, RST_PIN);

WiFiClientSecure espClient;
PubSubClient client(espClient);

// Global Variables
unsigned long servoDetachTimer = 0;
bool isServoMoving = false;
String doorStatus = "Closed";
unsigned long doorTimer = 0;
bool isDoorOpen = false;
bool motionActive = false;
bool isNightMode = false;
bool fanManualOverride = false;
float currentTemp = 0.0;
int currentHumidity = 0;
int currentDoorAngle = 0;
unsigned long lastDHTRead = 0;
unsigned long lastMqttReconnectAttempt = 0;
unsigned long lastWifiReconnectAttempt = 0;
const unsigned long mqttReconnectIntervalMs = 5000;
bool desiredLed1State = false;
bool desiredLed2State = false;
bool desiredLed3State = false;
bool motionLightBoostActive = false;
unsigned long motionLightBoostUntil = 0;
const unsigned long motionLightBoostMs = 5000;
const int ldrDarkThreshold = 1000;
const int ldrBrightThreshold = 1200;

void applyLedOutputs() {
  const bool forceLedsOn = motionLightBoostActive || isNightMode;
  digitalWrite(LIGHT1_LED, (forceLedsOn || desiredLed1State) ? HIGH : LOW);
  digitalWrite(LIGHT2_LED, (forceLedsOn || desiredLed2State) ? HIGH : LOW);
  digitalWrite(LIGHT3_LED, (forceLedsOn || desiredLed3State) ? HIGH : LOW);
}

// ===== 4. HELPER FUNCTIONS =====
void setRGB(int r, int g, int b) {
  ledcWrite(RGB_R, r);
  ledcWrite(RGB_G, g);
  ledcWrite(RGB_B, b);
}

void updateLCD() {
  DateTime now = rtc.now();
  lcd.setCursor(0, 0);
  if (isNightMode) lcd.print("MOON: NIGHT MODE");
  else if (currentTemp > tempThreshold) lcd.print("HOT! FAN ACTIVE ");
  else {
    int h12 = now.hour() % 12;
    if (h12 == 0) h12 = 12;
    String ampm = (now.hour() >= 12) ? "PM" : "AM";
    char timeBuf[20];
    sprintf(timeBuf, "T:%02d:%02d%s D:%s", h12, now.minute(), ampm.c_str(), isDoorOpen ? "OPN" : "CLS");
    lcd.print(timeBuf);
  }
  lcd.setCursor(0, 1);
  if (isDoorOpen) lcd.print(" ACCESS GRANTED ");
  else lcd.print("Temp: " + String(currentTemp, 0) + "C ");
}

void moveDoor(int angle) {
  if (angle > 180) angle = 180;
  if (angle < 0) angle = 0;

  ledcDetach(SERVO_PIN);
  ledcAttach(SERVO_PIN, 50, 14);

  if (currentDoorAngle < angle) {
    for (int a = currentDoorAngle; a <= angle; a += 2) {
      ledcWrite(SERVO_PIN, map(a, 0, 180, 410, 1966));
      delay(10);
    }
  } else {
    for (int a = currentDoorAngle; a >= angle; a -= 2) {
      ledcWrite(SERVO_PIN, map(a, 0, 180, 410, 1966));
      delay(10);
    }
  }

  currentDoorAngle = angle;
  isServoMoving = true;
  servoDetachTimer = millis();
}

void playSuccessSound() { tone(BUZZER_PIN, 1500, 150); delay(200); tone(BUZZER_PIN, 2000, 300); }
void playErrorSound() { tone(BUZZER_PIN, 200, 1000); }

String deviceTopic(const char *device, const char *suffix) {
  return String(topic_root) + "/" + String(device) + "/" + String(suffix);
}

bool isDeviceSetTopic(const String &topicStr, const char *device) {
  String setTopic = String("/") + String(device) + "/set";
  String legacyCommandTopic = String("/") + String(device) + "/command";
  return topicStr.endsWith(setTopic) || topicStr.endsWith(legacyCommandTopic);
}

void publishRetainedStatus(const char *device, const String &payload) {
  client.publish(deviceTopic(device, "status").c_str(), payload.c_str(), true);
}

void publishAck(const char *device, bool accepted, const char *detail) {
  String payload = "{\"accepted\":" + String(accepted ? "true" : "false") +
                   ",\"detail\":\"" + String(detail) +
                   "\",\"source\":\"esp32_gateway\"}";
  client.publish(deviceTopic(device, "ack").c_str(), payload.c_str(), false);
}

void refreshGaragePeer() {
  if (esp_now_is_peer_exist(garageAddress)) {
    esp_now_del_peer(garageAddress);
  }
  memcpy(garagePeerInfo.peer_addr, garageAddress, 6);
  garagePeerInfo.channel = WiFi.channel();
  garagePeerInfo.encrypt = false;
  esp_now_add_peer(&garagePeerInfo);
}

void learnGarageMacFrom(const uint8_t *srcAddr) {
  if (memcmp(garageAddress, srcAddr, 6) == 0) {
    return;
  }

  uint8_t oldGarageAddress[6];
  memcpy(oldGarageAddress, garageAddress, 6);
  if (esp_now_is_peer_exist(oldGarageAddress)) {
    esp_now_del_peer(oldGarageAddress);
  }

  memcpy(garageAddress, srcAddr, 6);
  refreshGaragePeer();

  Serial.print("Updated Garage MAC to: ");
  for (int i = 0; i < 6; i++) {
    if (garageAddress[i] < 16) Serial.print('0');
    Serial.print(garageAddress[i], HEX);
    if (i < 5) Serial.print(':');
  }
  Serial.println();
}

bool sendGarageCommandEspNow(const char *command) {
  strcpy(outgoingMsg.device, "garage");
  strcpy(outgoingMsg.command, command);
  outgoingMsg.value = 0;

  esp_err_t sendResult = esp_now_send(garageAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
  if (sendResult != ESP_OK) {
    refreshGaragePeer();
    sendResult = esp_now_send(garageAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
  }

  Serial.print("Garage command ");
  Serial.print(command);
  Serial.print(" send result: ");
  Serial.println((int)sendResult);
  return sendResult == ESP_OK;
}

// ── MQTT CALLBACK (From Flutter) ──
void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) message += (char)payload[i];
  String topicStr = String(topic);
  
  // 1. ESP-NOW Gateway Routing (Garage)
  if (isDeviceSetTopic(topicStr, "garage_door")) {
    bool openDoor = false;
    bool parsed = false;

    DynamicJsonDocument garageDoc(256);
    DeserializationError garageErr = deserializeJson(garageDoc, message);
    if (!garageErr) {
      if (garageDoc.containsKey("state")) {
        openDoor = garageDoc["state"] == true;
        parsed = true;
      } else if (garageDoc.containsKey("status")) {
        String status = garageDoc["status"].as<String>();
        status.toUpperCase();
        openDoor = (status == "OPEN" || status == "OPENING");
        parsed = true;
      }
    }

    if (!parsed) {
      String upper = message;
      upper.toUpperCase();
      if (upper.indexOf("OPEN") != -1 || upper.indexOf("TRUE") != -1) {
        openDoor = true;
        parsed = true;
      } else if (upper.indexOf("CLOSE") != -1 || upper.indexOf("FALSE") != -1) {
        openDoor = false;
        parsed = true;
      }
    }

    if (!parsed) {
      publishAck("garage_door", false, "invalid_garage_payload");
      return;
    }

    bool queued = sendGarageCommandEspNow(openDoor ? "OPEN" : "CLOSE");
    publishAck("garage_door", queued, queued ? "queued_to_espnow" : "espnow_send_failed");
    return;
  }
  
  // 2. ESP-NOW Gateway Routing (Garden)
  if (isDeviceSetTopic(topicStr, "garden_controls")) {
    strcpy(outgoingMsg.device, "garden");
    // Forward the raw JSON so garden node can parse it
    // Actually, dashboard sends commands to garden. If it's a pump command:
    if (message.indexOf("\"gardenPumpRunning\":true") != -1) { strcpy(outgoingMsg.command, "PUMP_ON"); }
    else if (message.indexOf("\"gardenPumpRunning\":false") != -1) { strcpy(outgoingMsg.command, "PUMP_OFF"); }
    else if (message.indexOf("\"firePumpRunning\":true") != -1) { strcpy(outgoingMsg.command, "FIRE_ON"); }
    else if (message.indexOf("\"firePumpRunning\":false") != -1) { strcpy(outgoingMsg.command, "FIRE_OFF"); }
    else if (message.indexOf("\"systemEnabled\":true") != -1) { strcpy(outgoingMsg.command, "SYS_ON"); }
    else if (message.indexOf("\"systemEnabled\":false") != -1) { strcpy(outgoingMsg.command, "SYS_OFF"); }
    else if (message.indexOf("\"autoGardenMode\":true") != -1) { strcpy(outgoingMsg.command, "AUTO_ON"); }
    else if (message.indexOf("\"autoGardenMode\":false") != -1) { strcpy(outgoingMsg.command, "AUTO_OFF"); }
    else return; // Don't send empty useless payloads
    
    outgoingMsg.value = 0;
    esp_err_t sendResult = esp_now_send(gardenAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
    publishAck("garden_controls", sendResult == ESP_OK, sendResult == ESP_OK ? "queued_to_espnow" : "espnow_send_failed");
    return;
  }

  // 3. Local Node Handling (Inside stuff)
  DynamicJsonDocument doc(512);
  DeserializationError error = deserializeJson(doc, message);
  if (error) return;

  bool handledLocalState = false;
  if (doc.containsKey("state")) {
    bool state = doc["state"];
    if (isDeviceSetTopic(topicStr, "led1")) {
      desiredLed1State = state;
      applyLedOutputs();
      handledLocalState = true;
      publishAck("led1", true, "state_applied");
    }
    else if (isDeviceSetTopic(topicStr, "led2")) {
      desiredLed2State = state;
      applyLedOutputs();
      handledLocalState = true;
      publishAck("led2", true, "state_applied");
    }
    else if (isDeviceSetTopic(topicStr, "led3")) {
      desiredLed3State = state;
      applyLedOutputs();
      handledLocalState = true;
      publishAck("led3", true, "state_applied");
    }
    else if (isDeviceSetTopic(topicStr, "fan")) { fanManualOverride = state; handledLocalState = true; publishAck("fan", true, "state_applied"); }
    else if (isDeviceSetTopic(topicStr, "tv")) { digitalWrite(TV_LED, state ? HIGH : LOW); handledLocalState = true; publishAck("tv", true, "state_applied"); }
    else if (isDeviceSetTopic(topicStr, "wash")) { digitalWrite(WASH_LED, state ? HIGH : LOW); handledLocalState = true; publishAck("wash", true, "state_applied"); }
    else if (isDeviceSetTopic(topicStr, "door")) {
      isDoorOpen = state;
      doorStatus = state ? "Open" : "Closed";
      moveDoor(state ? 180 : 0);
      if (state) playSuccessSound();
      handledLocalState = true;
      publishAck("door", true, "state_applied");
    }
  }

  if (isDeviceSetTopic(topicStr, "rgb")) {
    bool onState = doc["state"] | false;
    if (!onState) setRGB(0, 0, 0);
    else {
      int r = doc["r"] | 255; int g = doc["g"] | 255; int b = doc["b"] | 255;
      float br = doc["brightness"] | 1.0;
      setRGB(r * br, g * br, b * br);
    }
    publishAck("rgb", true, "state_applied");
  } else if (!handledLocalState) {
    publishAck("gateway", false, "unsupported_topic_or_payload");
  }
}

// ── ESP-NOW CALLBACK (From Nodes) ──
void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData, int len) {
  memcpy(&incomingMsg, incomingData, sizeof(incomingMsg));
  
  if (strcmp(incomingMsg.device, "garage") == 0) {
    learnGarageMacFrom(info->src_addr);

    if (strcmp(incomingMsg.command, "STATUS") == 0) {
      String payload = "{\"status\":\"" + String(incomingMsg.value == 1.0 ? "OPEN" : "CLOSED") + "\"}";
      publishRetainedStatus("garage_door", payload);
    } else if (strcmp(incomingMsg.command, "CAR") == 0) {
      String payload = "{\"carPresent\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garage_door", payload);
    } else if (strcmp(incomingMsg.command, "BLE") == 0) {
      String payload = "{\"bluetoothConnected\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garage_door", payload);
    }
  } 
  else if (strcmp(incomingMsg.device, "garden") == 0) {
    // Translate ESP-NOW garden data directly to MQTT JSON
    if (strcmp(incomingMsg.command, "SOIL") == 0) {
      String payload = "{\"soilMoisture\":" + String(incomingMsg.value) + "}";
      publishRetainedStatus("garden_sensors", payload);
    } else if (strcmp(incomingMsg.command, "SMOKE") == 0) {
      String payload = "{\"smokeLevel\":\"" + String(incomingMsg.value == 1.0 ? "HIGH" : "NORMAL") + "\"}";
      publishRetainedStatus("garden_sensors", payload);
    } else if (strcmp(incomingMsg.command, "TEMP") == 0) {
      String payload = "{\"gardenTemp\":" + String(incomingMsg.value) + "}";
      publishRetainedStatus("garden_sensors", payload);
    } else if (strcmp(incomingMsg.command, "WATER") == 0) {
      String payload = "{\"tankLevel\":" + String(incomingMsg.value) + "}";
      publishRetainedStatus("garden_sensors", payload);
    } else if (strcmp(incomingMsg.command, "P_STAT") == 0) {
      String payload = "{\"gardenPumpRunning\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garden_controls", payload);
    } else if (strcmp(incomingMsg.command, "F_STAT") == 0) {
      String payload = "{\"firePumpRunning\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garden_controls", payload);
    } else if (strcmp(incomingMsg.command, "A_STAT") == 0) {
      String payload = "{\"autoGardenMode\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garden_controls", payload);
    } else if (strcmp(incomingMsg.command, "S_STAT") == 0) {
      String payload = "{\"systemEnabled\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      publishRetainedStatus("garden_controls", payload);
    }
  }
}

bool reconnect() {
  String clientId = "ESP32-Gateway-" + String(random(0xffff), HEX);
  String willTopic = deviceTopic("gateway", "status");
  String willPayload = "{\"online\":false,\"source\":\"esp32_gateway\"}";

  if (client.connect(clientId.c_str(), mqtt_user, mqtt_password, willTopic.c_str(), 1, true, willPayload.c_str())) {
    client.subscribe((String(topic_root) + "/+/set").c_str());
    client.subscribe((String(topic_root) + "/+/command").c_str());
    client.publish(willTopic.c_str(), "{\"online\":true,\"source\":\"esp32_gateway\"}", true);
    return true;
  }

  return false;
}

// ===== 5. SETUP =====
void setup() {
  Serial.begin(115200);

  pinMode(TV_LED, OUTPUT); pinMode(WASH_LED, OUTPUT); pinMode(LIGHT1_LED, OUTPUT);
  pinMode(LIGHT2_LED, OUTPUT); pinMode(LIGHT3_LED, OUTPUT); pinMode(REAL_FAN_PIN, OUTPUT);
  pinMode(RGB_R, OUTPUT); pinMode(RGB_G, OUTPUT); pinMode(RGB_B, OUTPUT);
  pinMode(PIR_PIN, INPUT); pinMode(LDR_PIN, INPUT); pinMode(BUZZER_PIN, OUTPUT);

  ledcAttach(RGB_R, 5000, 8); ledcAttach(RGB_G, 5000, 8); ledcAttach(RGB_B, 5000, 8);
  moveDoor(0); 

  SPI.begin(); rfid.PCD_Init();
  Wire.begin(21, 22); lcd.init(); lcd.backlight();
  if (!rtc.begin()) Serial.println("Couldn't find RTC");
  dht.begin();

  // Core Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); }
  Serial.print("Gateway STA MAC: ");
  Serial.println(WiFi.macAddress());
  
  // Get actual channel from router
  uint8_t actual_chan = WiFi.channel();
  Serial.print("Gateway connected on channel: ");
  Serial.println(actual_chan);

  // 3. Init ESP-NOW
  if (esp_now_init() != ESP_OK) return;
  esp_now_register_recv_cb(OnDataRecv);

  // Register Garage
  memcpy(garagePeerInfo.peer_addr, garageAddress, 6);
  garagePeerInfo.channel = actual_chan;
  garagePeerInfo.encrypt = false;
  esp_now_add_peer(&garagePeerInfo);

  // Register Garden
  memcpy(gardenPeerInfo.peer_addr, gardenAddress, 6);
  gardenPeerInfo.channel = actual_chan;
  gardenPeerInfo.encrypt = false;
  esp_now_add_peer(&gardenPeerInfo);

  // 4. Init MQTT
  espClient.setCACert(emqx_ca_cert);
  client.setServer(mqtt_server, mqtt_port);
  client.setKeepAlive(20);
  client.setBufferSize(1024);
  client.setCallback(mqttCallback);
}

// ===== 6. LOOP =====
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    if (millis() - lastWifiReconnectAttempt >= mqttReconnectIntervalMs) {
      lastWifiReconnectAttempt = millis();
      WiFi.reconnect();
    }
    return;
  }

  if (!client.connected()) {
    if (millis() - lastMqttReconnectAttempt >= mqttReconnectIntervalMs) {
      lastMqttReconnectAttempt = millis();
      reconnect();
    }
  } else {
    client.loop();
  }

  if (isServoMoving && millis() - servoDetachTimer >= 2000) {
    isServoMoving = false;
    ledcDetach(SERVO_PIN);
  }

  if (millis() - lastDHTRead > 2500 || lastDHTRead == 0) {
    lastDHTRead = millis();
    float t = dht.readTemperature();
    int h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      currentTemp = t; currentHumidity = h;
    }
  }

  bool currentMotion = digitalRead(PIR_PIN);
  if (currentMotion) {
    motionLightBoostActive = true;
    motionLightBoostUntil = millis() + motionLightBoostMs;
    applyLedOutputs();
  }

  if (motionLightBoostActive && (long)(millis() - motionLightBoostUntil) >= 0) {
    motionLightBoostActive = false;
    applyLedOutputs();
  }

  if (currentMotion != motionActive) {
    motionActive = currentMotion;
    String motionPayload = "{\"motionDetected\":" + String(motionActive ? "true" : "false") + "}";
    publishRetainedStatus("home_sensors", motionPayload);
  }

  static unsigned long lastSensorUpdate = 0;
  if (millis() - lastSensorUpdate > 1000) {
    lastSensorUpdate = millis();
    String payload = "{\"temperature\":" + String(currentTemp) + ", \"humidity\":" + String(currentHumidity) + ", \"motionDetected\":" + String(motionActive ? "true" : "false") + "}";
    publishRetainedStatus("home_sensors", payload);
  }

  if (currentTemp > tempThreshold || fanManualOverride) digitalWrite(REAL_FAN_PIN, HIGH);
  else digitalWrite(REAL_FAN_PIN, LOW);

  int lightVal = analogRead(LDR_PIN);
  // Hysteresis avoids LED flicker when ambient light hovers around threshold.
  if (!isNightMode && lightVal < ldrDarkThreshold) {
    isNightMode = true;
    applyLedOutputs();
  } else if (isNightMode && lightVal > ldrBrightThreshold) {
    isNightMode = false;
    applyLedOutputs();
  }

  static unsigned long lastLCD = 0;
  if (millis() - lastLCD > 1000) { lastLCD = millis(); updateLCD(); }

  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String content = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
      content.concat(String(rfid.uid.uidByte[i] < 0x10 ? " 0" : " "));
      content.concat(String(rfid.uid.uidByte[i], HEX));
    }
    content.toUpperCase();
    if (content.substring(1) == authorizedUID) {
      playSuccessSound();
      isDoorOpen = true; doorStatus = "Open"; moveDoor(180);
    } else playErrorSound();
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
  }
}