#include <WiFi.h>
#include <esp_wifi.h>
#include <esp_mac.h>  // <-- ADD THIS LINE to fix the scope errors

void setup() {
  Serial.begin(115200);
  delay(2000); // Give Serial Monitor time to open
  
  Serial.println("\n\n--- ESP32 RELIABLE MAC FINDER ---");

  // Force minimum Wi-Fi initialization so mac routines exist natively
  WiFi.mode(WIFI_MODE_STA);
  
  // Method 1: Standard
  Serial.print("Board MAC Address (Standard): ");
  Serial.println(WiFi.macAddress());

  // Method 2: Internal ESP API (most reliable)
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  Serial.printf("Board MAC Address (Raw ESP API): %02X:%02X:%02X:%02X:%02X:%02X\n", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  
  Serial.println("-----------------------------------");
  Serial.println("Please write down the Raw ESP API address!");
}

void loop() {
  // Do nothing
}