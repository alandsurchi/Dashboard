#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <RTClib.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>

// ===== SETTINGS =====
const char* ssid = "Alo";
const char* password = "11111114";

#define TV_LED 16
#define WASH_LED 17
#define LIGHT1_LED 18
#define LIGHT2_LED 19

#define DHTPIN 4
#define DHTTYPE DHT11   
DHT dht(DHTPIN, DHTTYPE);

RTC_DS3231 rtc;
WebServer server(80);
LiquidCrystal_I2C lcd(0x27, 16, 2); 

// ===== TIME LOGIC =====
String getTimeString() {
  DateTime now = rtc.now();
  int h = now.hour();
  String ampm = (h >= 12) ? "PM" : "AM";
  h = h % 12; if (h == 0) h = 12; 
  char buf[30];
  sprintf(buf, "%02d:%02d:%02d %s", h, now.minute(), now.second(), ampm.c_str());
  return String(buf);
}

// ===== LCD UPDATE FUNCTION =====
void updateLCD() {
  DateTime now = rtc.now();
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  // Line 1: 12-hour Time
  int h12 = now.hour() % 12;
  if (h12 == 0) h12 = 12;
  String ampm = (now.hour() >= 12) ? "PM" : "AM";

  lcd.setCursor(0, 0);
  char timeBuf[16];
  sprintf(timeBuf, "Time: %02d:%02d %s", h12, now.minute(), ampm.c_str());
  lcd.print(timeBuf);

  // Line 2: Temp & Hum
  lcd.setCursor(0, 1);
  if (isnan(t)) {
    lcd.print("Sensor Error   ");
  } else {
    lcd.print(String(t, 0) + "C  Humid:" + String(h, 0) + "% ");
  }
}

// ===== WEB PAGE HTML =====
String page() {
  return R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<title>Baghdad Smart Home</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: 'Segoe UI', Arial; background: #1a1a2e; color: white; text-align: center; padding: 20px; }
  .container { background: #16213e; padding: 25px; border-radius: 20px; max-width: 400px; margin: auto; box-shadow: 0 8px 25px rgba(0,0,0,0.5); }
  h2 { color: #e94560; }
  .info { font-size: 18px; margin: 10px 0; background: #0f3460; padding: 12px; border-radius: 10px; }
  p { margin: 15px 0 5px 0; font-weight: bold; color: #add8e6; }
  button { width: 120px; padding: 14px; margin: 6px; border: none; border-radius: 8px; font-weight: bold; cursor: pointer; color: white; }
  .on { background: #28a745; } .off { background: #dc3545; }
</style>
<script>
setInterval(() => {
  fetch('/time').then(r=>r.text()).then(t=>{ document.getElementById('time').innerHTML = t; });
  fetch('/sensors').then(r=>r.text()).then(t=>{ document.getElementById('sensors').innerHTML = t; });
}, 1000);
function cmd(x){ fetch(x); }
</script>
</head>
<body>
<div class="container">
  <h2>Baghdad Smart Home</h2>
  <div class="info">Time: <span id="time">...</span></div>
  <div class="info">Weather: <span id="sensors">...</span></div>
  <hr style="border: 0.5px solid #0f3460;">
  <p>Television</p>
  <button class="on" onclick="cmd('/tv/on')">ON</button>
  <button class="off" onclick="cmd('/tv/off')">OFF</button>
  <p>Washing Machine</p>
  <button class="on" onclick="cmd('/wash/on')">ON</button>
  <button class="off" onclick="cmd('/wash/off')">OFF</button>
  <p>Light 1</p>
  <button class="on" onclick="cmd('/l1/on')">ON</button>
  <button class="off" onclick="cmd('/l1/off')">OFF</button>
  <p>Light 2</p>
  <button class="on" onclick="cmd('/l2/on')">ON</button>
  <button class="off" onclick="cmd('/l2/off')">OFF</button>
</div>
</body>
</html>
)rawliteral";
}

void setup() {
  Serial.begin(115200);
  pinMode(TV_LED, OUTPUT); pinMode(WASH_LED, OUTPUT);
  pinMode(LIGHT1_LED, OUTPUT); pinMode(LIGHT2_LED, OUTPUT);
  
  // Start I2C
  Wire.begin(21, 22);
  
  // Start LCD
  lcd.init();
  lcd.backlight();
  
  rtc.begin();
  dht.begin();
  
  WiFi.begin(ssid, password);
  while(WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  
  // Routes
  server.on("/", [](){ server.send(200, "text/html", page()); });
  server.on("/time", [](){ server.send(200, "text/plain", getTimeString()); });
  server.on("/sensors", [](){ 
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    server.send(200, "text/plain", String(t,1) + " C | Humidity: " + String(h,0) + "%"); 
  });
  server.on("/tv/on", [](){ digitalWrite(TV_LED, HIGH); server.send(200); });
  server.on("/tv/off", [](){ digitalWrite(TV_LED, LOW); server.send(200); });
  server.on("/wash/on", [](){ digitalWrite(WASH_LED, HIGH); server.send(200); });
  server.on("/wash/off", [](){ digitalWrite(WASH_LED, LOW); server.send(200); });
  server.on("/l1/on", [](){ digitalWrite(LIGHT1_LED, HIGH); server.send(200); });
  server.on("/l1/off", [](){ digitalWrite(LIGHT1_LED, LOW); server.send(200); });
  server.on("/l2/on", [](){ digitalWrite(LIGHT2_LED, HIGH); server.send(200); });
  server.on("/l2/off", [](){ digitalWrite(LIGHT2_LED, LOW); server.send(200); });

  server.begin();
}

void loop() {
  server.handleClient();
  
  // Update LCD every second
  static unsigned long lastLCD = 0;
  if (millis() - lastLCD > 1000) {
    lastLCD = millis();
    updateLCD();
  }
}