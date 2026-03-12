#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

// ---------------------------------------------------
// 1. PIN DEFINITIONS
// ---------------------------------------------------
const int mq2Pin = 35;       // Smoke Sensor (ADC1)
const int soilSensorPin = 32; // Soil Sensor (ADC1)
const int firePumpPin = 26;   // Pump 1 → ONLY for smoke/fire detection
const int soilPumpPin = 27;   // Pump 2 → ONLY for soil moisture

// ---------------------------------------------------
// 2. SETTINGS
// ---------------------------------------------------
int smokeThreshold = 3000;                    
const unsigned long fireTimerDuration = 10000; // 10 seconds burst for fire pump
const int soilLimitNoSoil = 3000;             // > this = no soil detected → safety off
const int soilLimitDry = 2400;                // Between dry and no-soil → water needed

const int NUM_SAMPLES = 64;                   // Averaging samples → fixes noise/false triggers

// Logic Variables
bool systemEnabled = true;
bool autoGardenMode = true; // Governs if the loop controls the pumps
bool firePumpActive = false;
unsigned long fireTurnOffTime = 0;
bool soilPumpOn = false;

// ── GATEWAY MAC ADDRESS ──
uint8_t gatewayAddress[] = {0xAC, 0x15, 0x18, 0xD5, 0xE7, 0xCC};
const char* AP_SSID = "Alo"; // Match the Gateway's router name

// ── ESP-NOW Structured Message ──
typedef struct struct_message {
  char device[16];
  char command[16];
  float value;
} struct_message;

struct_message outgoingMsg;
struct_message incomingMsg;
esp_now_peer_info_t peerInfo = {};

// ---------------------------------------------------
// 3. AVERAGED READING FUNCTION (fixes noise & false triggers)
// ---------------------------------------------------
int readAveraged(int pin) {
  unsigned long sum = 0;
  for (int i = 0; i < NUM_SAMPLES; i++) { sum += analogRead(pin); }
  return sum / NUM_SAMPLES;
}

// ---------------------------------------------------
// 4. ESP-NOW COMMUNICATION
// ---------------------------------------------------
void sendTelemetry(const char* command, float value) {
  strcpy(outgoingMsg.device, "garden");
  strcpy(outgoingMsg.command, command);
  outgoingMsg.value = value;
  esp_now_send(gatewayAddress, (uint8_t *)&outgoingMsg, sizeof(outgoingMsg));
}

// ── UPDATED: Callback when data is received ──
void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData, int len) {
  memcpy(&incomingMsg, incomingData, sizeof(incomingMsg));

  if (strcmp(incomingMsg.device, "garden") == 0) {
    if (strcmp(incomingMsg.command, "PUMP_ON") == 0) {
      digitalWrite(soilPumpPin, LOW); // ON
      soilPumpOn = true;
      sendTelemetry("P_STAT", 1.0);
    } else if (strcmp(incomingMsg.command, "PUMP_OFF") == 0) {
      digitalWrite(soilPumpPin, HIGH); // OFF
      soilPumpOn = false;
      sendTelemetry("P_STAT", 0.0);
    } else if (strcmp(incomingMsg.command, "FIRE_ON") == 0) {
      digitalWrite(firePumpPin, LOW); // ON
      firePumpActive = true;
      sendTelemetry("F_STAT", 1.0);
    } else if (strcmp(incomingMsg.command, "FIRE_OFF") == 0) {
      digitalWrite(firePumpPin, HIGH); // OFF
      firePumpActive = false;
      sendTelemetry("F_STAT", 0.0);
    } else if (strcmp(incomingMsg.command, "SYS_ON") == 0) {
      systemEnabled = true;
      Serial.println("System Enabled (Emergency Stop Disabled)");
    } else if (strcmp(incomingMsg.command, "SYS_OFF") == 0) {
      systemEnabled = false;
      Serial.println("System Disabled (Emergency Stop Engaged)");
    } else if (strcmp(incomingMsg.command, "AUTO_ON") == 0) {
      autoGardenMode = true;
    } else if (strcmp(incomingMsg.command, "AUTO_OFF") == 0) {
      autoGardenMode = false;
    }
  }
}

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

// ---------------------------------------------------
// 5. SETUP 
// ---------------------------------------------------
void setup() {
  Serial.begin(115200);

  pinMode(firePumpPin, OUTPUT);
  pinMode(soilPumpPin, OUTPUT);
  digitalWrite(firePumpPin, HIGH);  // OFF (active-low relay)
  digitalWrite(soilPumpPin, HIGH);  // OFF

  // Improve ADC accuracy
  analogSetPinAttenuation(mq2Pin, ADC_11db);
  analogSetPinAttenuation(soilSensorPin, ADC_11db);

  // ── IMPORTANT: Wi-Fi Channel Synchonization ──
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  int32_t channel = getWiFiChannel(AP_SSID);
  
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
  
  esp_now_register_recv_cb(OnDataRecv);

  // Register peer (Gateway)
  memcpy(peerInfo.peer_addr, gatewayAddress, 6);
  peerInfo.channel = channel;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add peer");
    return;
  }
  Serial.println("Garden ESP-NOW setup complete.");
}

// ---------------------------------------------------
// 6. LOOP 
// ---------------------------------------------------
void loop() {
  // Emergency stop → force everything off
  if (!systemEnabled) {
    digitalWrite(firePumpPin, HIGH);
    digitalWrite(soilPumpPin, HIGH);
    firePumpActive = false;
    soilPumpOn = false;
    return;
  }

  // Read averaged values (reduces noise → fixes false triggers)
  int smokeValue = readAveraged(mq2Pin);
  int soilValue = readAveraged(soilSensorPin);

  // Send Sensor Telemetry continuously to the Gateway
  static unsigned long lastSensorUpdate = 0;
  if (millis() - lastSensorUpdate > 3000) {
    lastSensorUpdate = millis();
    
    // Normalizing values for the app if necessary. Smoke is usually raw ADC, Moisture we can map
    float mappedMoisture = map(soilValue, 4095, 0, 0, 100); 
    
    sendTelemetry("SOIL", mappedMoisture);
    sendTelemetry("SMOKE", (smokeValue > smokeThreshold) ? 1.0 : 0.0);
    sendTelemetry("TEMP", 28.5); // Mocked temporarily as per original code
  }

  // --- FIRE PUMP LOGIC (independent, only smoke sensor) ---
  if (autoGardenMode) {
    if (smokeValue > smokeThreshold && !firePumpActive) {
      Serial.println("🔥 SMOKE DETECTED! Fire pump ON for 10s. Level: " + String(smokeValue));
      digitalWrite(firePumpPin, LOW);  // ON
      firePumpActive = true;
      fireTurnOffTime = millis() + fireTimerDuration;
      
      // Tell Gateway
      sendTelemetry("F_STAT", 1.0);
    }
    
    if (firePumpActive && millis() >= fireTurnOffTime) {
      digitalWrite(firePumpPin, HIGH);  // OFF
      firePumpActive = false;
      
      sendTelemetry("F_STAT", 0.0);
      Serial.println("Fire pump timed off.");
    }
  }

  // --- SOIL PUMP LOGIC (independent, only soil sensor) ---
  if (autoGardenMode) {
    bool shouldWater = (soilValue > soilLimitDry && soilValue <= soilLimitNoSoil);

    if (shouldWater) {
      digitalWrite(soilPumpPin, LOW);  // ON
      if (!soilPumpOn) {
        Serial.println("💧 Dry soil → Soil pump ON. Level: " + String(soilValue));
        soilPumpOn = true;
        sendTelemetry("P_STAT", 1.0);
      }
    } else {
      digitalWrite(soilPumpPin, HIGH); // OFF
      if (soilPumpOn) {
        String reason = (soilValue > soilLimitNoSoil) ? "NO SOIL" : "WET ENOUGH";
        Serial.println("Soil pump OFF (" + reason + "). Level: " + String(soilValue));
        soilPumpOn = false;
        sendTelemetry("P_STAT", 0.0);
      }
    }
  }
}