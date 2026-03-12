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
const char *mqtt_server = "i2022f00.ala.eu-central-1.emqxsl.com";
const int mqtt_port = 8883;
const char *mqtt_user = "flutter_app";
const char *mqtt_password = "Smart1Eco.";
const char *my_uid = "8LvpNY7wzEYXhw4JtmPZLiML9Zc2";
constexpr uint8_t WIFI_CHAN = 1;

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
unsigned long lastDHTRead = 0;

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
  int dutyCycle = map(angle, 0, 180, 410, 1966);
  ledcAttach(SERVO_PIN, 50, 14);
  ledcWrite(SERVO_PIN, dutyCycle);
  isServoMoving = true;
  servoDetachTimer = millis();
}

void playSuccessSound() { tone(BUZZER_PIN, 1500, 150); delay(200); tone(BUZZER_PIN, 2000, 300); }
void playErrorSound() { tone(BUZZER_PIN, 200, 1000); }

// ── MQTT CALLBACK (From Flutter) ──
void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) message += (char)payload[i];
  String topicStr = String(topic);
  
  // 1. ESP-NOW Gateway Routing (Garage)
  if (topicStr.endsWith("/garage_door/command")) {
    message.toUpperCase();
    strcpy(outgoingMsg.device, "garage");
    if (message.indexOf("OPEN") != -1 || message.indexOf("TRUE") != -1) strcpy(outgoingMsg.command, "OPEN");
    else strcpy(outgoingMsg.command, "CLOSE");
    outgoingMsg.value = 0;
    esp_now_send(garageAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
    return;
  }
  
  // 2. ESP-NOW Gateway Routing (Garden)
  if (topicStr.endsWith("/garden_controls/command")) {
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
    esp_now_send(gardenAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
    return;
  }

  // 3. Local Node Handling (Inside stuff)
  DynamicJsonDocument doc(512);
  DeserializationError error = deserializeJson(doc, message);
  if (error) return;

  if (doc.containsKey("state")) {
    bool state = doc["state"];
    if (topicStr.endsWith("/led1/command")) digitalWrite(LIGHT1_LED, state ? HIGH : LOW);
    else if (topicStr.endsWith("/led2/command")) digitalWrite(LIGHT2_LED, state ? HIGH : LOW);
    else if (topicStr.endsWith("/led3/command")) digitalWrite(LIGHT3_LED, state ? HIGH : LOW);
    else if (topicStr.endsWith("/fan/command")) fanManualOverride = state;
    else if (topicStr.endsWith("/tv/command")) digitalWrite(TV_LED, state ? HIGH : LOW);
    else if (topicStr.endsWith("/wash/command")) digitalWrite(WASH_LED, state ? HIGH : LOW);
    else if (topicStr.endsWith("/door/command")) {
      isDoorOpen = state;
      doorStatus = state ? "Open" : "Closed";
      doorTimer = state ? millis() : 0;
      moveDoor(state ? 180 : 0);
      if (state) playSuccessSound();
    }
  }

  if (topicStr.endsWith("/rgb/command")) {
    bool onState = doc["state"] | false;
    if (!onState) setRGB(0, 0, 0);
    else {
      int r = doc["r"] | 255; int g = doc["g"] | 255; int b = doc["b"] | 255;
      float br = doc["brightness"] | 1.0;
      setRGB(r * br, g * br, b * br);
    }
  }
}

// ── ESP-NOW CALLBACK (From Nodes) ──
void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData, int len) {
  memcpy(&incomingMsg, incomingData, sizeof(incomingMsg));
  
  if (strcmp(incomingMsg.device, "garage") == 0) {
    if (strcmp(incomingMsg.command, "STATUS") == 0) {
      String payload = "{\"status\":\"" + String(incomingMsg.value == 1.0 ? "OPEN" : "CLOSED") + "\"}";
      client.publish(("home/" + String(my_uid) + "/garage_door/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "CAR") == 0) {
      String payload = "{\"carPresent\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      client.publish(("home/" + String(my_uid) + "/garage_door/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "BLE") == 0) {
      String payload = "{\"bluetoothConnected\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      client.publish(("home/" + String(my_uid) + "/garage_door/status").c_str(), payload.c_str());
    }
  } 
  else if (strcmp(incomingMsg.device, "garden") == 0) {
    // Translate ESP-NOW garden data directly to MQTT JSON
    if (strcmp(incomingMsg.command, "SOIL") == 0) {
      String payload = "{\"soilMoisture\":" + String(incomingMsg.value) + "}";
      client.publish(("home/" + String(my_uid) + "/garden_sensors/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "SMOKE") == 0) {
      String payload = "{\"smokeLevel\":\"" + String(incomingMsg.value == 1.0 ? "HIGH" : "NORMAL") + "\"}";
      client.publish(("home/" + String(my_uid) + "/garden_sensors/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "TEMP") == 0) {
      String payload = "{\"gardenTemp\":" + String(incomingMsg.value) + "}";
      client.publish(("home/" + String(my_uid) + "/garden_sensors/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "P_STAT") == 0) {
      String payload = "{\"gardenPumpRunning\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      client.publish(("home/" + String(my_uid) + "/garden_controls/status").c_str(), payload.c_str());
    } else if (strcmp(incomingMsg.command, "F_STAT") == 0) {
      String payload = "{\"firePumpRunning\":" + String(incomingMsg.value == 1.0 ? "true" : "false") + "}";
      client.publish(("home/" + String(my_uid) + "/garden_controls/status").c_str(), payload.c_str());
    }
  }
}

void reconnect() {
  while (!client.connected()) {
    String clientId = "ESP32-Gateway-" + String(random(0xffff), HEX);
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_password)) {
      client.subscribe(("home/" + String(my_uid) + "/+/command").c_str()); // Wildcard for all commands
    } else {
      delay(5000);
    }
  }
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

  // 1. Core Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); }
  
  // Get actual channel from router
  uint8_t actual_channel = WiFi.channel();
  Serial.print("Gateway connected on channel: ");
  Serial.println(actual_channel);

  // Note: The ESP32 is connected to the Access Point. 
  // It is already operating on the exact channel of the AP.
  // We do NOT call esp_wifi_set_channel here to avoid hardware driver conflicts.

  // 3. Init ESP-NOW
  if (esp_now_init() != ESP_OK) return;
  esp_now_register_recv_cb(OnDataRecv);

  // Register Garage
  memcpy(garagePeerInfo.peer_addr, garageAddress, 6);
  garagePeerInfo.channel = actual_channel;
  garagePeerInfo.encrypt = false;
  esp_now_add_peer(&garagePeerInfo);

  // Register Garden
  memcpy(gardenPeerInfo.peer_addr, gardenAddress, 6);
  gardenPeerInfo.channel = actual_channel;
  gardenPeerInfo.encrypt = false;
  esp_now_add_peer(&gardenPeerInfo);

  // 4. Init MQTT
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
}

// ===== 6. LOOP =====
void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  if (isServoMoving && millis() - servoDetachTimer >= 1000) {
    isServoMoving = false;
    ledcWrite(SERVO_PIN, 0); ledcDetach(SERVO_PIN);
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
  if (currentMotion != motionActive) {
    motionActive = currentMotion;
    String motionPayload = "{\"motionDetected\":" + String(motionActive ? "true" : "false") + "}";
    client.publish(("home/" + String(my_uid) + "/home_sensors/status").c_str(), motionPayload.c_str());
  }

  static unsigned long lastSensorUpdate = 0;
  if (millis() - lastSensorUpdate > 3000) {
    lastSensorUpdate = millis();
    String payload = "{\"temperature\":" + String(currentTemp) + ", \"humidity\":" + String(currentHumidity) + ", \"motionDetected\":" + String(motionActive ? "true" : "false") + "}";
    client.publish(("home/" + String(my_uid) + "/home_sensors/status").c_str(), payload.c_str());
  }

  if (currentTemp > tempThreshold || fanManualOverride) digitalWrite(REAL_FAN_PIN, HIGH);
  else digitalWrite(REAL_FAN_PIN, LOW);

  int lightVal = analogRead(LDR_PIN);
  isNightMode = (lightVal < 1000);

  static unsigned long lastLCD = 0;
  if (millis() - lastLCD > 1000) { lastLCD = millis(); updateLCD(); }

  if (isDoorOpen && millis() - doorTimer > 4000) {
    isDoorOpen = false; doorStatus = "Closed"; moveDoor(0);
  }

  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String content = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
      content.concat(String(rfid.uid.uidByte[i] < 0x10 ? " 0" : " "));
      content.concat(String(rfid.uid.uidByte[i], HEX));
    }
    content.toUpperCase();
    if (content.substring(1) == authorizedUID) {
      playSuccessSound();
      isDoorOpen = true; doorStatus = "Open"; doorTimer = millis(); moveDoor(180);
    } else playErrorSound();
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
  }
}