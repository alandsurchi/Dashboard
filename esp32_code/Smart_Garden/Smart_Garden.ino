#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

// ---------------------------------------------------
// 1. PIN DEFINITIONS
// ---------------------------------------------------
const int mq2Pin = 35;       // Smoke Sensor (ADC1)
const int mq2DoPin = 34;     // Smoke Sensor DO (digital threshold output)
const int soilSensorPin = 32; // Soil Sensor (ADC1)
const int waterLevelPin = 33; // Water tank level sensor (S pin, ADC1)
const int firePumpPin = 26;   // Pump 1 → ONLY for smoke/fire detection
const int soilPumpPin = 27;   // Pump 2 → ONLY for soil moisture

// ---------------------------------------------------
// 2. SETTINGS
// ---------------------------------------------------
const int smokeMinTrigger = 2000;             // Ignore smaller ADC fluctuations
const int smokeDeltaTrigger = 350;            // Trigger above moving baseline + delta
const unsigned long smokeConfirmMs = 800;     // Require stable condition before state changes
const float smokeBaselineAlpha = 0.03f;       // Baseline adaptation speed
const bool smokeUseDigitalTrigger = true;     // Recommended: MQ2 DO pin for reliable threshold trigger
const bool smokeUseAnalogTrigger = false;     // Optional AO-based trigger (can be noisy)
const bool smokeDoActiveLow = true;           // If DO logic is inverted on your module, set this to false
const unsigned long smokePumpRunMs = 10000;   // Run fire pump for 10s after smoke confirmation
const unsigned long smokeCooldownMs = 10000;  // Wait period before listening for smoke again
const int soilLimitNoSoil = 4000;             // >= this likely means probe disconnected / no soil
const bool soilRawDryIsLow = true;            // Your logs show dry soil as very low raw values
const bool soilUsePercentControl = false;     // Keep false for this sensor; raw check is more reliable
const int soilWetPercentThreshold = 25;       // Used only if soilUsePercentControl=true
const int soilWetRawThresholdLow = 140;       // If raw >= this, soil is considered wet (low-is-dry sensors)
const int soilWetRawThresholdHigh = 2600;     // If raw <= this, soil is considered wet (high-is-dry sensors)

// Water level calibration for your specific sensor in tank.
// Adjust these after first readings from Serial Monitor.
const int waterRawEmpty = 1200;
const int waterRawFull = 3000;
const bool waterLevelInverted = false;

const int NUM_SAMPLES = 64;                   // Averaging samples → fixes noise/false triggers

// Logic Variables
bool systemEnabled = true;
bool autoGardenMode = true; // Governs if the loop controls the pumps
bool firePumpActive = false;
bool soilPumpOn = false;
bool smokeAlarmLatched = false;
bool fireManualOverride = false;
bool smokeCycleActive = false;
bool smokeCooldownActive = false;
float smokeBaseline = 0.0f;
unsigned long smokeHighSince = 0;
unsigned long smokeCycleStartMs = 0;
unsigned long smokeCooldownStartMs = 0;
bool soilProbeConfirmed = false;

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
esp_now_peer_info_t peerInfo = {};

// ---------------------------------------------------
// 3. AVERAGED READING FUNCTION (fixes noise & false triggers)
// ---------------------------------------------------
int readAveraged(int pin) {
  unsigned long sum = 0;
  for (int i = 0; i < NUM_SAMPLES; i++) { sum += analogRead(pin); }
  return sum / NUM_SAMPLES;
}

int mapSoilMoisturePercent(int raw) {
  // Moisture percent is always normalized as 0=dry, 100=wet.
  int moisture = soilRawDryIsLow ? map(raw, 0, 4095, 0, 100) : map(raw, 4095, 0, 0, 100);
  return constrain(moisture, 0, 100);
}

float mapWaterLevelPercent(int raw) {
  if (waterRawEmpty == waterRawFull) return 0.0;

  int minRaw = min(waterRawEmpty, waterRawFull);
  int maxRaw = max(waterRawEmpty, waterRawFull);
  int clamped = constrain(raw, minRaw, maxRaw);

  float percent = (float)(clamped - minRaw) * 100.0f / (float)(maxRaw - minRaw);
  if (waterLevelInverted) {
    percent = 100.0f - percent;
  }
  return constrain(percent, 0.0f, 100.0f);
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
      autoGardenMode = false;  // *** Disable auto so loop doesn't override ***
      digitalWrite(soilPumpPin, LOW); // ON
      soilPumpOn = true;
      sendTelemetry("P_STAT", 1.0);
    } else if (strcmp(incomingMsg.command, "PUMP_OFF") == 0) {
      autoGardenMode = false;  // *** Disable auto so loop doesn't override ***
      digitalWrite(soilPumpPin, HIGH); // OFF
      soilPumpOn = false;
      sendTelemetry("P_STAT", 0.0);
    } else if (strcmp(incomingMsg.command, "FIRE_ON") == 0) {
      autoGardenMode = false;  // *** Disable auto so loop doesn't override ***
      digitalWrite(firePumpPin, LOW); // ON
      firePumpActive = true;
      smokeAlarmLatched = false;
      fireManualOverride = true;
      smokeCycleActive = false;
      smokeCooldownActive = false;
      smokeHighSince = 0;
      sendTelemetry("F_STAT", 1.0);
    } else if (strcmp(incomingMsg.command, "FIRE_OFF") == 0) {
      autoGardenMode = false;  // *** Disable auto so loop doesn't override ***
      digitalWrite(firePumpPin, HIGH); // OFF
      firePumpActive = false;
      smokeAlarmLatched = false;
      fireManualOverride = false;
      smokeCycleActive = false;
      smokeCooldownActive = false;
      smokeHighSince = 0;
      sendTelemetry("F_STAT", 0.0);
    } else if (strcmp(incomingMsg.command, "SYS_ON") == 0) {
      systemEnabled = true;
      sendTelemetry("S_STAT", 1.0);
      Serial.println("System Enabled (Emergency Stop Disabled)");
    } else if (strcmp(incomingMsg.command, "SYS_OFF") == 0) {
      systemEnabled = false;
      // Force pumps off immediately (don't wait for next loop())
      digitalWrite(firePumpPin, HIGH);
      digitalWrite(soilPumpPin, HIGH);
      firePumpActive = false;
      soilPumpOn = false;
      fireManualOverride = false;
      smokeAlarmLatched = false;
      smokeCycleActive = false;
      smokeCooldownActive = false;
      smokeHighSince = 0;
      soilProbeConfirmed = false;
      sendTelemetry("S_STAT", 0.0);
      Serial.println("System Disabled (Emergency Stop Engaged)");
    } else if (strcmp(incomingMsg.command, "AUTO_ON") == 0) {
      autoGardenMode = true;
      fireManualOverride = false;
      sendTelemetry("A_STAT", 1.0);
    } else if (strcmp(incomingMsg.command, "AUTO_OFF") == 0) {
      autoGardenMode = false;
      sendTelemetry("A_STAT", 0.0);
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
  pinMode(mq2DoPin, INPUT);
  digitalWrite(firePumpPin, HIGH);  // OFF (active-low relay)
  digitalWrite(soilPumpPin, HIGH);  // OFF

  // Improve ADC accuracy
  analogSetPinAttenuation(mq2Pin, ADC_11db);
  analogSetPinAttenuation(soilSensorPin, ADC_11db);
  analogSetPinAttenuation(waterLevelPin, ADC_11db);

  // Build initial smoke baseline from clean-air startup readings (AO mode).
  if (smokeUseAnalogTrigger) {
    long smokeInitSum = 0;
    for (int i = 0; i < 12; i++) {
      smokeInitSum += readAveraged(mq2Pin);
      delay(20);
    }
    smokeBaseline = (float)smokeInitSum / 12.0f;
    Serial.print("Smoke baseline initialized: ");
    Serial.println(smokeBaseline, 1);
  } else {
    Serial.println("Smoke trigger mode: DO only");
  }

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
    fireManualOverride = false;
    smokeAlarmLatched = false;
    smokeCycleActive = false;
    smokeCooldownActive = false;
    smokeHighSince = 0;
    soilProbeConfirmed = false;
    return;
  }

  // Read averaged values (reduces noise → fixes false triggers)
  int smokeValue = readAveraged(mq2Pin);
  int smokeDoRaw = digitalRead(mq2DoPin);
  bool smokeDoTriggered = smokeDoActiveLow ? (smokeDoRaw == LOW) : (smokeDoRaw == HIGH);
  int soilValue = readAveraged(soilSensorPin);
  int soilMoisturePercent = mapSoilMoisturePercent(soilValue);
  int waterRawValue = readAveraged(waterLevelPin);
  float tankLevelPercent = mapWaterLevelPercent(waterRawValue);

  // Send Sensor Telemetry continuously to the Gateway
  static unsigned long lastSensorUpdate = 0;
  if (millis() - lastSensorUpdate > 2000) {
    lastSensorUpdate = millis();

    sendTelemetry("SOIL", soilMoisturePercent);
    sendTelemetry("SMOKE", smokeAlarmLatched ? 1.0 : 0.0);
    sendTelemetry("WATER", tankLevelPercent);
    sendTelemetry("TEMP", 28.5); // Mocked temporarily as per original code
  }

  static unsigned long lastDebugPrint = 0;
  if (millis() - lastDebugPrint > 3000) {
    lastDebugPrint = millis();
    Serial.print("SmokeRaw=");
    Serial.print(smokeValue);
    Serial.print(" SmokeDO=");
    Serial.print(smokeDoTriggered ? "TRIG" : "IDLE");
    Serial.print(" SmokeBase=");
    Serial.print(smokeBaseline, 1);
    Serial.print(" SoilRaw=");
    Serial.print(soilValue);
    Serial.print(" Soil%=");
    Serial.print(soilMoisturePercent);
    Serial.print(" Auto=");
    Serial.print(autoGardenMode ? "ON" : "OFF");
    Serial.print(" FirePump=");
    Serial.print(firePumpActive ? "ON" : "OFF");
    Serial.print(" SmokeState=");
    if (smokeCycleActive) Serial.print("ACTIVE");
    else if (smokeCooldownActive) Serial.print("COOLDOWN");
    else Serial.print("LISTEN");
    Serial.print(" SoilProbe=");
    Serial.print(soilProbeConfirmed ? "CONFIRMED" : "UNCONFIRMED");
    if (soilRawDryIsLow) {
      Serial.print(" WetRaw>=");
      Serial.print(soilWetRawThresholdLow);
      if (soilUsePercentControl) {
        Serial.print(" Wet%>=");
        Serial.print(soilWetPercentThreshold);
      }
    } else {
      Serial.print(" WetRaw<=");
      Serial.print(soilWetRawThresholdHigh);
      if (soilUsePercentControl) {
        Serial.print(" Wet%>=");
        Serial.print(soilWetPercentThreshold);
      }
    }
    Serial.print(" Rule=");
    Serial.print("NOT_WET=>PUMP_ON");
    Serial.print(" SoilPump=");
    Serial.println(soilPumpOn ? "ON" : "OFF");
  }

  // --- FIRE PUMP LOGIC (safety path, independent of autoGardenMode) ---
  if (smokeUseAnalogTrigger && !smokeAlarmLatched && !fireManualOverride && !smokeCooldownActive) {
    smokeBaseline = (1.0f - smokeBaselineAlpha) * smokeBaseline + smokeBaselineAlpha * (float)smokeValue;
  }

  int dynamicTrigger = (int)smokeBaseline + smokeDeltaTrigger;

  bool smokeAboveTriggerAnalog = false;
  if (smokeUseAnalogTrigger) {
    smokeAboveTriggerAnalog = (smokeValue >= smokeMinTrigger) && (smokeValue >= dynamicTrigger);
  }

  bool smokeTriggerSignal =
      (smokeUseDigitalTrigger && smokeDoTriggered) ||
      (smokeUseAnalogTrigger && smokeAboveTriggerAnalog);

  if (fireManualOverride && !firePumpActive) {
    digitalWrite(firePumpPin, LOW);  // ON
    firePumpActive = true;
    sendTelemetry("F_STAT", 1.0);
    Serial.println("Fire pump ON (manual override)");
  }

  if (!fireManualOverride) {
    if (smokeCycleActive) {
      if (millis() - smokeCycleStartMs >= smokePumpRunMs) {
        smokeCycleActive = false;
        smokeAlarmLatched = false;
        smokeCooldownActive = true;
        smokeCooldownStartMs = millis();
        smokeHighSince = 0;

        if (firePumpActive) {
          digitalWrite(firePumpPin, HIGH);  // OFF
          firePumpActive = false;
          sendTelemetry("F_STAT", 0.0);
        }
        Serial.println("Smoke cycle complete -> entering cooldown wait");
      }
    } else if (smokeCooldownActive) {
      if (millis() - smokeCooldownStartMs >= smokeCooldownMs) {
        smokeCooldownActive = false;
        smokeHighSince = 0;
        Serial.println("Smoke cooldown complete -> listening resumed");
      }
    } else {
      if (smokeTriggerSignal) {
        if (smokeHighSince == 0) {
          smokeHighSince = millis();
        }
        if (millis() - smokeHighSince >= smokeConfirmMs) {
          smokeAlarmLatched = true;
          smokeCycleActive = true;
          smokeCycleStartMs = millis();
          smokeHighSince = 0;

          if (!firePumpActive) {
            digitalWrite(firePumpPin, LOW);  // ON
            firePumpActive = true;
            sendTelemetry("F_STAT", 1.0);
          }
          Serial.println("Smoke confirmed -> fire pump ON for 10s cycle");
        }
      } else {
        smokeHighSince = 0;
      }
    }
  }

  // --- SOIL SYSTEM ---
  if (autoGardenMode) {
    int soilRaw = soilValue; // already averaged
    // Thresholds (adjust as needed for your sensor)
    const int NO_SOIL_THRESHOLD = 4000; // probe disconnected or not in soil
    const int DRY_SOIL_THRESHOLD = 600; // dry if above this

    if (soilRaw >= NO_SOIL_THRESHOLD) {
      Serial.println("🌬️ No Soil detected - Soil pump OFF");
      digitalWrite(soilPumpPin, HIGH); // OFF
      soilPumpOn = false;
      sendTelemetry("P_STAT", 0.0);
    } else if (soilRaw > DRY_SOIL_THRESHOLD) {
      Serial.println("🌱 Dry Soil - Soil pump ON");
      digitalWrite(soilPumpPin, LOW); // ON
      soilPumpOn = true;
      sendTelemetry("P_STAT", 1.0);
    } else {
      Serial.println("💧 Wet Soil - Soil pump OFF");
      digitalWrite(soilPumpPin, HIGH); // OFF
      soilPumpOn = false;
      sendTelemetry("P_STAT", 0.0);
    }
    Serial.print("Soil Sensor: ");
    Serial.println(soilRaw);
  }
}