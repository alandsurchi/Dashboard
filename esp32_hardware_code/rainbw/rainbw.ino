#include <WiFi.h>
#include <WebServer.h>

// ------------------- USER SETTINGS -------------------
const char* ssid     = "Alo";      
const char* password = "11111114";  
// -----------------------------------------------------

const int redPin = 23;
const int greenPin = 22;
const int bluePin = 21;

const int freq = 5000;
const int resolution = 8;

int currentMode = 0; // 0=Static, 1=Rainbow, 2=Flash
int animSpeed = 50;  // Delay in milliseconds

WebServer server(80);

// Modern HTML/CSS Design
const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE html><html>
<head><title>RGB Master</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: 'Segoe UI', sans-serif; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); color: white; text-align: center; margin: 0; padding: 20px; }
  .card { background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); border-radius: 20px; padding: 30px; max-width: 400px; margin: auto; box-shadow: 0 8px 32px 0 rgba(0,0,0,0.8); }
  h1 { margin-bottom: 30px; color: #00d2ff; text-transform: uppercase; letter-spacing: 2px; }
  .btn { background: #0f3460; border: 1px solid #00d2ff; color: white; padding: 12px 20px; width: 80%; font-size: 16px; margin: 10px; cursor: pointer; border-radius: 50px; transition: 0.3s; }
  .btn:hover { background: #e94560; border-color: #e94560; box-shadow: 0 0 15px #e94560; }
  input[type=color] { width: 120px; height: 120px; border: none; border-radius: 50%; background: none; cursor: pointer; margin: 20px; }
  .slider-label { margin-top: 20px; display: block; font-size: 14px; color: #aaa; }
  input[type=range] { width: 80%; cursor: pointer; margin: 15px; }
</style>
</head>
<body>
  <div class="card">
    <h1>RGB Controller</h1>
    
    <input type="color" id="picker" onchange="sendColor(this.value)">
    
    <button class="btn" onclick="sendMode(1)">Rainbow Mode</button>
    <button class="btn" onclick="sendMode(2)">Party Flash</button>
    <button class="btn" onclick="sendMode(0)">Turn OFF</button>
    
    <label class="slider-label">Animation Speed</label>
    <input type="range" min="1" max="100" value="50" onchange="sendSpeed(this.value)">
  </div>

<script>
  function sendColor(hex) {
    fetch('/update?color=' + hex.replace('#', ''));
  }
  function sendMode(m) {
    fetch('/mode?v=' + m);
  }
  function sendSpeed(s) {
    // We invert the value so higher slider = faster (lower delay)
    let delay = 101 - s;
    fetch('/speed?v=' + delay);
  }
</script>
</body></html>
)rawliteral";

void setup() {
  Serial.begin(115200);
  ledcAttach(redPin, freq, resolution);
  ledcAttach(greenPin, freq, resolution);
  ledcAttach(bluePin, freq, resolution);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  
  Serial.println("\nConnected! IP: " + WiFi.localIP().toString());

  server.on("/", []() { server.send(200, "text/html", index_html); });
  
  server.on("/update", []() {
    currentMode = 0; 
    String hex = server.arg("color");
    long num = (long) strtol(hex.c_str(), NULL, 16);
    setRGB(num >> 16, num >> 8 & 0xFF, num & 0xFF);
    server.send(200);
  });

  server.on("/mode", []() {
    currentMode = server.arg("v").toInt();
    if(currentMode == 0) setRGB(0,0,0);
    server.send(200);
  });

  server.on("/speed", []() {
    animSpeed = server.arg("v").toInt();
    server.send(200);
  });

  server.begin();
}

void loop() {
  server.handleClient();
  if (currentMode == 1) rainbowCycle();
  if (currentMode == 2) flashMode();
}

void setRGB(int r, int g, int b) {
  ledcWrite(redPin, r);
  ledcWrite(greenPin, g);
  ledcWrite(bluePin, b);
}

void rainbowCycle() {
  static int hue = 0;
  static unsigned long lastTime = 0;
  if (millis() - lastTime > animSpeed) {
    lastTime = millis();
    hue++;
    if (hue > 255) hue = 0;
    if (hue < 85) setRGB(hue * 3, 255 - hue * 3, 0);
    else if (hue < 170) { int h = hue - 85; setRGB(255 - h * 3, 0, h * 3); }
    else { int h = hue - 170; setRGB(0, h * 3, 255 - h * 3); }
  }
}

void flashMode() {
  static int state = 0;
  static unsigned long lastTime = 0;
  if (millis() - lastTime > (animSpeed * 5)) { // Flash is a bit slower than rainbow
    lastTime = millis();
    state++;
    if (state > 2) state = 0;
    if (state == 0) setRGB(255, 0, 0);
    if (state == 1) setRGB(0, 255, 0);
    if (state == 2) setRGB(0, 0, 255);
  }
}