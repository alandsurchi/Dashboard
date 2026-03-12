# Dashbord Project Architecture & Connections

This document provides a full, detailed explanation of how your smart home project works, the servers it uses, and how all the components are connected together.

## 1. High-Level Overview

Your project is a distributed IoT Smart Home system with three main layers:
1. **Frontend (User Interface):** A Flutter dashboard (mobile/web) connected to Firebase (for authentication) and EMQX (for real-time device control).
2. **Cloud Infrastructure (Servers):** Firebase for user management and an EMQX Cloud MQTT broker for real-time, bidirectional messaging between the app and the hardware.
3. **Hardware (ESP32 Network):** A master-slave architecture using multiple ESP32 microcontrollers. One ESP32 acts as the **Gateway** connecting to Wi-Fi and MQTT, while the other ESP32s communicate with the Gateway offline using **ESP-NOW**.

---

## 2. Servers & Cloud Infrastructure

### **Firebase**
- **Usage in Flutter:** Handles user authentication (Login/Registration) and database storage via Firestore.
- **Why it's used:** It securely provides a unique User ID (`uid`) for each user. This `uid` is critically important because it is used to create unique MQTT topics (e.g., `home/uid/...`), ensuring that one user's dashboard only controls their own home.

### **EMQX Cloud MQTT Broker**
- **Server Address:** `i2022f00.ala.eu-central-1.emqxsl.com`
- **Authentication:** Username: `flutter_app` | Password: `Smart1Eco.`
- **Flutter Connection:** The Flutter app connects to this broker using **WebSockets over SSL (WSS)** on port `8084` via the `mqtt_client` package.
- **ESP32 Connection:** The main Gateway ESP32 connects to this broker using **MQTTS (Secure MQTT/TLS)** on port `8883` using the `WiFiClientSecure` and `PubSubClient` libraries.
- **Why it's used:** MQTT is extremely lightweight and fast. It acts as the central router. When you press a button on the dashboard, it publishes a message to EMQX. EMQX instantly pushes that message to the connected Gateway ESP32.

---

## 3. Hardware Architecture (ESP-NOW + MQTT Bridge)

You are using a very efficient architecture where not every ESP32 connects to your Wi-Fi router. Instead, only ONE device connects to Wi-Fi, acting as a bridge.

### **Node 1: The "Inside" Node (The Gateway)**
- **Role:** The Brain / MQTT Bridge.
- **Connections:** 
  - Connects to your home Wi-Fi (`Alo`).
  - Connects to the EMQX MQTT Broker securely.
  - Initializes **ESP-NOW** on Wi-Fi Channel 1 to broadcast and receive data to/from local nodes.
- **Local Duties:** It directly controls the inside house features (Living room LEDs, TV, Washing Machine, Fan, main door servo, RFID scanner, DHT11 temp/humidity, LDR for night mode, and PIR motion sensor).
- **Routing Duties:**
  - When it receives a command from the Flutter app meant for the **Garage** or **Garden**, it parses the JSON data, packages it into a small [struct_message](file:///c:/Users/aland/Desktop/Dr.hasan/Dashbord/esp32_code/inside/inside.ino#31-36), and beams it over radio frequency to the respective node using ESP-NOW.
  - When the Garage or Garden nodes send status updates back via ESP-NOW, this Gateway converts those raw updates into JSON format and publishes them to the MQTT broker so the Flutter app can read them.

### **Node 2: The "Garage" Node**
- **Role:** Independent Sub-Node.
- **Connections:** **Does not connect to Wi-Fi or MQTT.** It only communicates via ESP-NOW directly to the Gateway's MAC Address (`AC:15:18:D5:E7:CC`).
- **Duties:** 
  - Controls the garage door servo motor.
  - Uses an ultrasonic sensor to calculate the distance and detect if a car is present.
  - Broadcasts a **BLE (Bluetooth Low Energy)** signal as a server (`Garage_Key`). If the owner's phone connects to this BLE signal AND the ultrasonic sensor detects a car, the garage door auto-opens.
  - Sends status updates (Door open/closed, Car presence, BLE connection status) back to the Gateway via ESP-NOW.

### **Node 3: The "Garden" Node**
- **Role:** Independent Sub-Node.
- **Connections:** Communicates exclusively via ESP-NOW to the Gateway.
- **Duties:** 
  - Reads soil moisture, temperature, and smoke levels.
  - Controls the garden water pump and emergency fire pump.
  - Sends immediate alerts (like high smoke) back to the Gateway, which in turn publishes them to the Flutter dashboard via MQTT.

---

## 4. How the Communication Flows (Step-by-Step)

Here is exactly what happens when you press the "Open Garage" button on your Flutter Dashboard:

1. **Dashboard (Flutter):** The [MqttService](file:///c:/Users/aland/Desktop/Dr.hasan/Dashbord/lib/services/mqtt_service.dart#6-150) takes the command, formats it as JSON (`{"state": true}`), and publishes it to the EMQX broker on the topic `home/[YOUR_UID]/garage_door/command`.
2. **Cloud (EMQX):** The broker receives the message and pushes it down to the "Inside" Gateway ESP32, which is subscribed to all `home/[UID]/+/command` topics.
3. **Gateway (Inside ESP32):** 
   - Receives the MQTT message.
   - Realizes the topic ends with `/garage_door/command`.
   - Instead of trying to flip a pin locally, it creates an ESP-NOW message with destination = `garage` and command = `OPEN`.
   - Transmits this packet silently and instantly over Wi-Fi Channel 1 via ESP-NOW.
4. **Sub-Node (Garage ESP32):**
   - The [OnDataRecv](file:///c:/Users/aland/Desktop/Dr.hasan/Dashbord/esp32_code/garage_auto/garage_auto.ino#92-111) callback triggers because it received the ESP-NOW packet.
   - It sees the command is `OPEN`.
   - It fires the [moveDoor(true)](file:///c:/Users/aland/Desktop/Dr.hasan/Dashbord/esp32_code/inside/inside.ino#112-121) function, turning the servo motor to open the garage.
   - Once the door is fully open, it uses ESP-NOW to send a message back: `{"status": "OPEN"}`.
5. **Gateway (Inside ESP32) -> Flutter:** The Gateway receives the ESP-NOW update, formulates a JSON MQTT message, and publishes it to `home/[YOUR_UID]/garage_door/status`. The Flutter app receives this and updates the UI button to show the door is open.

## Summary

This architecture is highly professional. By using **ESP-NOW**, you significantly reduce the load on your local Wi-Fi router, reduce latency, and make the sub-nodes (Garage, Garden) incredibly fast and power-efficient since they don't have to maintain heavy TCP/IP and SSL handshakes with an MQTT broker. Everything goes through your robust "Inside" Gateway.
