#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#define TRIG_PIN 27
#define ECHO_PIN 26
#define SERVO_PIN 25
#define BUTTON_PIN 13

#define DISTANCE_THRESHOLD 50   // cm
#define CONFIRMATION_DELAY 1500 // ms

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// ── GATEWAY MAC ADDRESS ──
uint8_t gatewayAddress[] = {0xAC, 0x15, 0x18, 0xD5, 0xE7, 0xCC};
constexpr uint8_t WIFI_CHAN = 1;

// ── ESP-NOW Structured Message ──
typedef struct struct_message {
  char device[16];
  char command[16];
  float value;
} struct_message;

struct_message outgoingMsg;
struct_message incomingMsg;
esp_now_peer_info_t peerInfo;

// ── Servo (non-blocking) ──
unsigned long servoDetachTimer = 0;
bool isServoMoving = false;

// ── State ──
bool deviceConnected = false;
bool garageIsOpen = false;
int currentDistance = 400;
unsigned long detectionStartTime = 0;

BLEServer *pServer = NULL;

void moveDoor(bool open) {
  int angle = open ? 180 : 0;
  if (angle > 180) angle = 180;
  if (angle < 0) angle = 0;

  int dutyCycle = map(angle, 0, 180, 410, 1966);
  ledcAttach(SERVO_PIN, 50, 14);
  ledcWrite(SERVO_PIN, dutyCycle);

  isServoMoving = true;
  servoDetachTimer = millis();

  garageIsOpen = open;
  Serial.println(open ? "ACTION: Opening Door" : "ACTION: Closing Door");
}

int getDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long dur = pulseIn(ECHO_PIN, HIGH, 30000);
  int dist = dur * 0.034 / 2;
  return (dist == 0 || dist > 400) ? 400 : dist;
}

// Send Status to Gateway
void sendStatus() {
  strcpy(outgoingMsg.device, "garage");
  
  // Send Garage State
  strcpy(outgoingMsg.command, "STATUS");
  outgoingMsg.value = garageIsOpen ? 1.0 : 0.0;
  esp_now_send(gatewayAddress, (uint8_t *) &outgoingMsg, sizeof(outgoingMsg));

  // Send Car Presence
  strcpy(outgoingMsg.command, "CAR");
  outgoingMsg.value = (currentDistance < DISTANCE_THRESHOLD) ? 1.0 : 0.0;
  esp_now_send(gatewayAddress, (uint8_t *) &outgoingMsg, sizeof(outgoingMsg));

  // Send Bluetooth Status
  strcpy(outgoingMsg.command, "BLE");
  outgoingMsg.value = deviceConnected ? 1.0 : 0.0;
  esp_now_send(gatewayAddress, (uint8_t *) &outgoingMsg, sizeof(outgoingMsg));
}

// ── UPDATED: Callback when data is received ──
void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData, int len) {
  memcpy(&incomingMsg, incomingData, sizeof(incomingMsg));
  Serial.print("ESP-NOW RX: device=");
  Serial.print(incomingMsg.device);
  Serial.print(" cmd=");
  Serial.print(incomingMsg.command);
  Serial.print(" val=");
  Serial.println(incomingMsg.value);
  
  if (strcmp(incomingMsg.device, "garage") == 0) {
    if (strcmp(incomingMsg.command, "OPEN") == 0) {
      if (!garageIsOpen) moveDoor(true);
    } 
    else if (strcmp(incomingMsg.command, "CLOSE") == 0) {
      if (garageIsOpen) moveDoor(false);
    }
  }
}

// Callback when data is sent
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  // Optional debugging
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
    Serial.println("BLE: Phone connected");
  }
  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    Serial.println("BLE: Phone disconnected");
    pServer->getAdvertising()->start();
  }
};

int32_t getWiFiChannel(const char *ssid) {
  if (int32_t n = WiFi.scanNetworks()) {
    for (uint8_t i = 0; i < n; i++) {
      if (!strcmp(ssid, WiFi.SSID(i).c_str())) {
        return WiFi.channel(i);
      }
    }
  }
  return 1; // Default fallback
}

void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // ── IMPORTANT: Wi-Fi Channel Synchonization ──
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  int32_t channel = getWiFiChannel("Alo");
  
  // Enforce channel change using promiscuous mode
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(channel, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);
  
  Serial.print("ESP-NOW synced to Router Channel: ");
  Serial.println(channel);

  // Init ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }
  
  // ── UPDATED: Explicitly cast the send callback to stop compiler strictness ──
  esp_now_register_send_cb((esp_now_send_cb_t)OnDataSent);
  esp_now_register_recv_cb(OnDataRecv);

  // Register peer (Gateway)
  memcpy(peerInfo.peer_addr, gatewayAddress, 6);
  peerInfo.channel = channel;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add peer");
    return;
  }
  
  // ── BLE ──
  BLEDevice::init("Garage_Key");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  moveDoor(false); // Initial close
  Serial.println("Garage ESP-NOW setup complete.");
}

void loop() {
  if (isServoMoving && millis() - servoDetachTimer >= 1000) {
    isServoMoving = false;
    ledcWrite(SERVO_PIN, 0); 
    ledcDetach(SERVO_PIN);
    sendStatus(); 
  }

  static unsigned long lastDistCheck = 0;
  if (millis() - lastDistCheck > 1000) {
    lastDistCheck = millis();
    currentDistance = getDistance();
  }

  static bool lastButtonState = HIGH;
  static unsigned long lastDebounceTime = 0;
  bool reading = digitalRead(BUTTON_PIN);
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  if ((millis() - lastDebounceTime) > 50) {
    static bool buttonState = HIGH;
    if (reading != buttonState) {
      buttonState = reading;
      if (buttonState == LOW && !isServoMoving) { 
        moveDoor(!garageIsOpen);
        delay(500); // Give it time to start moving
        sendStatus(); 
      }
    }
  }
  lastButtonState = reading;

  if (!garageIsOpen && !isServoMoving) {
    bool bothActive = (deviceConnected && currentDistance < DISTANCE_THRESHOLD);
    if (bothActive) {
      if (detectionStartTime == 0) detectionStartTime = millis();
      else if (millis() - detectionStartTime > CONFIRMATION_DELAY) {
        moveDoor(true);
        detectionStartTime = 0;
      }
    } else {
      detectionStartTime = 0;
    }
  } else {
    detectionStartTime = 0;
  }

  static unsigned long lastUpdate = 0;
  if (!isServoMoving && millis() - lastUpdate > 2000) {
    lastUpdate = millis();
    sendStatus();
  }
}