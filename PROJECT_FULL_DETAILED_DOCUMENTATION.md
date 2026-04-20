# Dashbord Project - Full Detailed Technical Documentation

Date: 2026-04-18

## 1) What This Project Is

This repository contains a complete smart home IoT system made of:

- A Flutter dashboard application (mobile, web, desktop capable via Flutter scaffolding)
- Firebase services for authentication and persisted per-user device state
- EMQX Cloud MQTT broker for real-time command and telemetry transport
- Three ESP32 firmware programs:
  - Home gateway and local home controller (`Home_Control.ino`)
  - Smart garage node (`Smart_garage.ino`)
  - Smart garden node (`Smart_Garden.ino`)

The system is designed so users control home devices from a dashboard, while sensor updates flow back in near real time.

## 2) High-Level Architecture

The architecture is distributed and layered:

1. Presentation and UX layer
   - Flutter UI screens and widgets.

2. Application and state layer
   - Provider + ChangeNotifier (`DashboardState`, `AuthService`, `MqttService`).

3. Cloud and messaging layer
   - Firebase Auth + Firestore.
   - EMQX Cloud MQTT broker over TLS / WSS.

4. Edge and hardware layer
   - ESP32 gateway node (Wi-Fi + MQTT + ESP-NOW bridge).
   - ESP32 garage node (ESP-NOW + BLE + ultrasonic + servo).
   - ESP32 garden node (ESP-NOW + smoke + soil + relays).

### 2.1 Runtime Topology

- Flutter app authenticates users with Firebase.
- Flutter app connects to EMQX and publishes commands under `home/main/...` topics.
- Gateway ESP32 subscribes to set/command topics and either:
  - controls local home hardware directly, or
  - forwards commands to garage/garden nodes via ESP-NOW.
- Garage and garden nodes send telemetry/status via ESP-NOW back to gateway.
- Gateway republishes that telemetry/status to EMQX topics consumed by Flutter.
- Firestore stores logical device state under `users/{uid}/devices`.

## 3) Technology Stack and What Is Used

## 3.1 Flutter / Dart Packages (from `pubspec.yaml`)

- `provider`: state management and dependency wiring.
- `firebase_core`, `firebase_auth`, `cloud_firestore`: auth and persisted per-user state.
- `firebase_database`: live sensor feed (display-oriented realtime ingestion).
- `mqtt_client`: MQTT transport for mobile/desktop (`MqttServerClient`) and web (`MqttBrowserClient`).
- `http`: legacy direct REST to local ESP endpoints (`ApiService`, `WaterScreen`).
- `google_fonts`: typography.
- `flutter_colorpicker`: RGB color selection UI.
- `fl_chart`: declared, currently not visibly used in the scanned screens.

## 3.2 Embedded / Arduino Libraries

Gateway (`Home_Control.ino`) uses:

- `WiFi.h`, `WiFiClientSecure.h`, `PubSubClient.h`: secure MQTT connectivity.
- `esp_now.h`, `esp_wifi.h`: low-latency node-to-node control/telemetry.
- `ArduinoJson.h`: JSON payload parsing from MQTT.
- `DHT.h`, `RTClib.h`, `LiquidCrystal_I2C.h`, `MFRC522.h`, plus `SPI.h`, `Wire.h`.

Garage node (`Smart_garage.ino`) uses:

- `esp_now.h`, `WiFi.h`, `esp_wifi.h`: ESP-NOW communication and channel sync.
- `BLEDevice.h`, `BLEServer.h`, `BLEUtils.h`: BLE presence-based authorization signal.

Garden node (`Smart_Garden.ino`) uses:

- `esp_now.h`, `WiFi.h`, `esp_wifi.h`.
- Analog sensor averaging and active-low relay control logic.

## 3.3 Cloud Services

- Firebase project (from `firebase_options.dart`): `smarteco-8d700`.
- Firestore rules enforce user ownership boundaries.
- Realtime Database is integrated for live sensor ingestion in app state.
- EMQX dedicated broker host in Flutter/ESP32 code:
  - `tf897ef8.ala.dedicated.aws.emqxcloud.com`

## 4) Repository Structure (Functional View)

- `lib/`
  - `main.dart`: app bootstrap, provider graph, auth routing.
  - `screens/`: all UI feature pages.
  - `services/`: auth, mqtt, firestore, global dashboard state.
  - `widgets/`: reusable UI blocks.
  - `utils/constants.dart`: legacy IP constants.
- `esp32_code/`
  - `Home_Control/Home_Control.ino`: gateway + inside-home controls.
  - `Smart_garage/Smart_garage.ino`: garage node.
  - `Smart_Garden/Smart_Garden.ino`: garden node.
- `firestore.rules`: per-user read/write ACL.
- `emqxcloud-ca.crt`: TLS certificate asset used by Flutter IO MQTT client.
- Platform folders (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`) are Flutter scaffold outputs.
- `test/` is currently empty.

## 5) Flutter Application Architecture

## 5.1 Bootstrap and Provider Graph (`lib/main.dart`)

Initialization sequence:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.web)`
3. `MultiProvider` dependency tree

Providers registered:

- `FirestoreService` (plain Provider)
- `AuthService` (ChangeNotifier)
- `MqttService` (ChangeNotifier via conditional export)
- `DashboardState` via `ChangeNotifierProxyProvider3`

Important design decision in code:

- `DashboardState` instance is reused in the proxy `update` callback.
- Dependencies are refreshed by `updateDependencies(...)` instead of recreating state.
- This avoids state reset on frequent MQTT updates.

## 5.2 Authentication Flow (`lib/services/auth_service.dart`)

- Uses `FirebaseAuth.instance`.
- Supports sign-in with email/password.
- Exposes `authStateChanges` stream.
- Maintains loading/error state for login UI.
- Sign-out calls Firebase `signOut()`.

UI routing logic:

- If auth stream has user -> `HomeScreen`.
- If no user -> `LoginScreen`.

## 5.3 Global App State (`lib/services/dashboard_state.dart`)

`DashboardState` is the main orchestrator for:

- Home control states (LEDs, fan, TV, washer, RGB, door, motion, climate).
- Garage states (door status, lock, car presence, BLE state, auto open/close).
- Garden states (soil, smoke, pumps, auto modes, safety).
- UI support states (clock timer, logs, schedules).

Key patterns implemented:

1. Dependency updates
   - `updateDependencies` detects auth instance changes and re-initializes cloud services only when needed.

2. Initial cloud sync
   - On login, if UID exists:
     - connect MQTT,
     - initialize default Firestore docs,
     - perform one-time Firestore snapshot load then cancel stream.

3. Optimistic updates
   - `_updateFB(...)` updates local state first, notifies UI immediately, then writes Firestore and publishes MQTT.

4. Partial payload-safe parser
   - `_parseDeviceData(...)` only mutates fields when keys are present, preventing accidental reset of sibling values.

5. MQTT inbound mapping
   - Handles topic suffixes:
     - `/home_sensors/status`
     - `/garage_door/status`
     - `/garden_sensors/status`
     - `/garden_controls/status`

6. Realtime Database live sensor stream
  - Uses `FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: ...)`.
  - Supports runtime path resolution via template (including `{uid}` token).
  - Parses nested payloads using key normalization and alias matching.
  - Updates home and garden display fields from live feed when present.
  - Falls back to MQTT per-field when RTDB field is absent.

7. Garage automation reliability logic
  - Auto-open evaluation from live status changes (`bluetoothConnected + carPresent + closed`).
  - Auto-close evaluation when condition is lost while door is open.
  - Cooldown guards prevent repeated open/close command spam.
  - Garage history is runtime-driven (no hardcoded entries).

## 5.4 Messaging Service (`lib/services/mqtt_service_*.dart`)

### Mobile/Desktop (`mqtt_service_io.dart`)

- Uses `MqttServerClient` over TLS (port `8883`).
- Loads CA cert from asset `emqxcloud-ca.crt`.
- Has reconnect timer every 5 seconds.
- Subscribes to:
  - `home/main/+/status`
  - `home/main/+/ack`
- Publishes commands to:
  - `home/main/{deviceId}/set`
- Publishes online/offline presence to:
  - `home/main/dashboard/status`

### Web (`mqtt_service_web.dart`)

- Uses WSS endpoint `wss://tf897ef8.ala.dedicated.aws.emqxcloud.com/mqtt` on port `8084`.
- Similar subscription/publishing behavior to IO variant.
- Browser trust store handles TLS trust for WSS.

### Shared entry (`mqtt_service.dart`)

- Conditional export selects web or IO implementation automatically.

## 5.4.1 Runtime Defines Used in App

- MQTT:
  - `MQTT_USERNAME`
  - `MQTT_PASSWORD`
- Realtime Database:
  - `RTDB_URL`
  - `RTDB_SENSOR_PATH`

## 5.5 Firestore Layer (`lib/services/firestore_service.dart`)

Collection layout per user:

- `users/{uid}/devices/{deviceId}`

Default seed documents when first user is initialized:

- Home: `led1`, `led2`, `led3`, `fan`, `tv`, `wash`, `rgb`, `home_sensors`, `door`
- Garage: `garage_door`, `garage_settings`
- Garden: `garden_sensors`, `garden_controls`

Update method uses merge semantics:

- `set(data, SetOptions(merge: true))`

## 5.6 UI Layer (`lib/screens/*`)

Primary navigation (`home_screen.dart`):

- `HomeControlScreen`
- `SmartGarageScreen`
- `SmartGardenScreen`

Also present but currently not in active home navigation:

- `GarageScreen`
- `EnergyScreen`
- `WaterScreen`

Feature summaries:

- Home Control:
  - Time/climate cards, night mode, light/appliance toggles, RGB picker, door controls, motion status, schedule builder.
- Smart Garage:
  - Door open/close, lock, auto-open/auto-close, BLE and car detection indicators, history.
- Smart Garden:
  - Soil/smoke stats, climate, tank level, pump controls, auto mode, emergency stop.

Reusable widgets:

- `CustomCard`: frosted-style card container.
- `StatusBadge`: small status capsule with optional icon.

## 6) MQTT Topic and Payload Contract

Topic root in current code:

- `home/main`

## 6.1 Command Topics

- `home/main/led1/set`
- `home/main/led2/set`
- `home/main/led3/set`
- `home/main/fan/set`
- `home/main/tv/set`
- `home/main/wash/set`
- `home/main/rgb/set`
- `home/main/door/set`
- `home/main/garage_door/set`
- `home/main/garden_controls/set`

Legacy compatibility in gateway callback:

- `.../command` suffix is also accepted.

## 6.2 Status Topics

- `home/main/home_sensors/status`
- `home/main/garage_door/status`
- `home/main/garden_sensors/status`
- `home/main/garden_controls/status`
- `home/main/gateway/status`
- `home/main/dashboard/status`

## 6.3 Ack Topics

- `home/main/{device}/ack`

Gateway sends ack payloads like:

- `{"accepted":true|false,"detail":"...","source":"esp32_gateway"}`

## 6.4 Command Payload Examples

- LED/Fan/TV/Wash/Door style:
  - `{"state":true}`
- RGB style:
  - `{"state":true,"r":255,"g":0,"b":0,"brightness":0.8,"ts":"..."}`
- Garden control style:
  - `{"gardenPumpRunning":true,"ts":"..."}`

## 7) ESP32 Firmware Architecture

## 7.1 Gateway Node - Home_Control (`esp32_code/Home_Control/Home_Control.ino`)

Core role:

- Local home controller + MQTT edge client + ESP-NOW bridge.

Local hardware responsibilities:

- Lighting outputs: LED1/LED2/LED3, RGB channels.
- Appliance outputs: TV, washing indicator/output, fan relay/output.
- Door control: servo + RFID access.
- Sensors: DHT11, PIR motion, LDR, RTC display logic on I2C LCD.
- Buzzer feedback for RFID success/fail.

Networking responsibilities:

- Connects Wi-Fi STA.
- Uses TLS MQTT to EMQX with CA certificate.
- Subscribes to `home/main/+/set` and `home/main/+/command`.
- Routes garage/garden commands over ESP-NOW.
- Translates ESP-NOW telemetry back into MQTT status payloads.

Command routing behavior:

- `garage_door` set/command -> robust parse from JSON or legacy text, then convert to ESP-NOW command `OPEN`/`CLOSE`.
- `garden_controls` set/command -> map JSON fields to ESP-NOW command tokens:
  - `PUMP_ON`, `PUMP_OFF`, `FIRE_ON`, `FIRE_OFF`, `SYS_ON`, `SYS_OFF`, `AUTO_ON`, `AUTO_OFF`.
- Local devices are handled directly by pin updates and servo motion.

Reliability enhancements implemented:

- Learns garage ESP-NOW MAC dynamically from inbound garage packets.
- Refreshes/re-adds garage peer and retries ESP-NOW send on failure.
- Emits explicit ack detail for malformed garage payloads.

Loop behavior highlights:

- Resilient Wi-Fi and MQTT reconnect loops.
- Periodic DHT read.
- Motion change events immediately published.
- Periodic sensor status publish every ~3 seconds.
- Fan auto behavior: ON when temp above threshold or manual override.
- LDR-driven `isNightMode` state for LCD/logic.

## 7.2 Garage Node (`esp32_code/Smart_garage/Smart_garage.ino`)

Core role:

- Dedicated garage actuator/sensor node without direct MQTT.

Functions:

- Receives ESP-NOW open/close commands from gateway.
- Drives garage servo with smooth angle transition.
- Reads ultrasonic distance for car presence.
- Broadcasts BLE server (`Garage_Key`) and tracks connection status.
- Supports physical button door toggle (debounced logic).
- Supports local fallback auto-open when BLE connected and car detected.
- Supports local condition-loss auto-close (after confirmation delay).
- Sends telemetry triplet to gateway:
  - door status (`STATUS`)
  - car presence (`CAR`)
  - BLE connected (`BLE`)

Reliability design:

- Synchronizes ESP-NOW channel by scanning router SSID channel.
- Periodic status retransmission every ~2 seconds when idle.

## 7.3 Garden Node (`esp32_code/Smart_Garden/Smart_Garden.ino`)

Core role:

- Autonomous environmental safety and irrigation controller with remote overrides.

Sensors and actuators:

- MQ-2 smoke sensor (DO-first mode, AO optional).
- Soil moisture sensor (analog).
- Fire pump relay (active-low).
- Soil water pump relay (active-low).

Control logic:

- `systemEnabled` acts as emergency stop gate.
- `autoGardenMode` controls whether local auto logic manages pumps.
- Manual commands from gateway disable auto mode to avoid immediate overwrite.
- Smoke handling uses cycle mode:
  - confirm smoke,
  - run fire pump for 10 seconds,
  - cooldown wait,
  - resume listening.
- Soil pump logic is intentionally simplified to direct rule:
  - if sensor is not wet and not disconnected -> pump ON,
  - if wet or disconnected -> pump OFF.
- Soil thresholds are calibrated for current probe polarity (`soilRawDryIsLow=true`).

Telemetry sent to gateway:

- `SOIL` moisture (mapped 0-100)
- `SMOKE` high/normal flag
- `TEMP` currently mocked as `28.5`
- status flags: `P_STAT`, `F_STAT`, `A_STAT`, `S_STAT`

## 8) End-to-End Communication Flows

## 8.1 Example A - Home LED Toggle

1. User toggles LED in Home Control screen.
2. `DashboardState.toggleLedX(...)` calls `_updateFB('ledX', {'state': ...})`.
3. UI updates immediately (optimistic update).
4. Firestore document is merged.
5. MQTT command published to `home/main/ledX/set`.
6. Gateway receives command and writes pin HIGH/LOW.
7. Gateway sends ack on `home/main/ledX/ack`.

## 8.2 Example B - Open Garage Door

1. User taps OPEN in Smart Garage screen.
2. Dashboard publishes `home/main/garage_door/set`.
3. Gateway routes to ESP-NOW command `OPEN` for garage node.
4. Garage servo opens; node sends `STATUS`, `CAR`, `BLE` updates.
5. Gateway converts to MQTT retained updates on `garage_door/status`.
6. App receives status and refreshes UI.

## 8.3 Example C - Motion Sensor Event

1. PIR changes on gateway.
2. Gateway publishes `home_sensors/status` with motion field.
3. Flutter MQTT handler updates `motionDetected` and timestamp.
4. Optional persistence writes to Firestore `home_sensors` doc.

## 8.4 Example D - Garden Smoke Event

1. Garden node confirms smoke trigger (DO-first, AO optional fallback).
2. Fire pump starts and runs a fixed 10-second cycle.
3. Fire pump stops and node enters smoke cooldown wait.
4. After cooldown, node resumes smoke listening.
5. Telemetry `SMOKE` and `F_STAT` sent over ESP-NOW.
6. Gateway republishes to `garden_sensors/status` and `garden_controls/status`.
7. Dashboard state updates smoke/pump indicators.

## 8.5 Example E - Garden Soil Pump Rule (Current)

1. Garden node reads soil sensor raw value.
2. Node evaluates simple rule:
  - not wet and not disconnected => ON,
  - wet or disconnected => OFF.
3. Pump status (`P_STAT`) is sent when state changes.
4. Gateway republishes control status for dashboard.

## 9) Security Model and Access Control

## 9.1 Firestore Security

Current rules:

- Only authenticated user can read/write own subtree:
  - `users/{userId}/**` allowed when `request.auth.uid == userId`.

## 9.2 MQTT Security

- TLS enabled for ESP32 and Flutter IO path.
- WSS for Flutter web path.
- Credentials are currently present in code defaults and must be replaced for production.

## 9.3 Current Security Risks Observed

- Wi-Fi credentials are hardcoded in ESP32 source.
- MQTT credentials are hardcoded/defaulted in both Flutter and ESP32 source.
- Firebase API configuration is embedded (normal for client apps, but still needs proper rules and app restrictions).
- Existing docs mention older host/user values that do not fully match current code in every place.

## 10) Build, Run, and Platform Notes

- Flutter multi-platform scaffold exists for Android, iOS, web, Linux, macOS, Windows.
- Android config is mostly default template values (`com.example.dashbord`, debug signing in release block).
- `main.dart` initializes Firebase with `DefaultFirebaseOptions.web` explicitly.
  - This is acceptable for web, but mobile/desktop usually use `DefaultFirebaseOptions.currentPlatform` in generated FlutterFire setups.

MQTT runtime defines supported by Flutter:

- `MQTT_USERNAME`
- `MQTT_PASSWORD`

Realtime Database runtime defines supported by Flutter:

- `RTDB_URL`
- `RTDB_SENSOR_PATH`

Example:

- `flutter run --dart-define=MQTT_USERNAME=... --dart-define=MQTT_PASSWORD=...`
- `flutter run --dart-define=MQTT_USERNAME=... --dart-define=MQTT_PASSWORD=... --dart-define=RTDB_URL=... --dart-define=RTDB_SENSOR_PATH=...`

## 11) Data Model Summary (Firestore)

Path:

- `users/{uid}/devices/{deviceId}`

Key docs and representative fields:

- `led1|led2|led3`: `state`
- `fan|tv|wash`: `state`
- `rgb`: `state`, `brightness`, `color` or `r/g/b`
- `home_sensors`: `temperature`, `humidity`, `motionDetected`
- `door`: `status`
- `garage_door`: `status`, `carPresent`, `locked`, `bluetoothConnected`
- `garage_settings`: `autoOpen`, `autoClose`, `autoCloseTimer`
- `garden_sensors`: `soilMoisture`, `smokeLevel`, `gardenTemp`, `gardenHumidity`, `tankLevel`
- `garden_controls`: `gardenPumpRunning`, `firePumpRunning`, `autoGardenMode`, `autoFireMode`, `systemEnabled`

## 12) Quality and Maintenance Status (Observed)

1. Active app path appears to be centered on:
   - `HomeControlScreen`, `SmartGarageScreen`, `SmartGardenScreen`.

2. Some files appear legacy or alternative UI variants:
   - `EnergyScreen`, `GarageScreen`, `WaterScreen`, `ApiService`, `AppConstants`.

3. Static analysis logs in root indicate historical/alternate-code warnings and errors.
   - `analyze.txt` appears stale relative to current file snapshots.

4. Test directory is empty.

5. Firmware behavior has been heavily tuned for field reliability.
  - Garage command/peer robustness and local fallback logic were added.
  - Garden smoke and soil logic were simplified/tuned to match real sensor behavior.

## 13) Mismatch Notes vs Existing Documentation

Existing docs in repository contain useful guidance but include inconsistencies with current source:

- `architecture_explanation.md` references different hosts, topic roots, and paths from the currently scanned codebase.
- `MQTT_TLS_EMQX_SETUP.md` generally aligns with TLS and authentication goals, but some values differ from hardcoded values in source.
- `gole` describes an architecture where all ESP32 devices use MQTT directly; current code uses gateway+ESP-NOW hybrid architecture.

## 14) Practical Improvement Roadmap

High-value next improvements:

1. Secrets and credentials
   - Move Wi-Fi and MQTT credentials out of source for both app and firmware.

2. Firebase initialization
   - Switch to platform-aware Firebase options if targeting non-web clients.

3. Topic namespace per user/home
   - Use UID-scoped or site-scoped topic root (currently static `home/main`).

4. Reliability and observability
   - Add structured logging and command correlation IDs.
   - Add retained startup state for all critical device statuses.

5. Testing and CI
   - Add widget tests and basic service tests.
   - Add static analysis and formatting checks in CI.

6. Data contract hardening
   - Formalize JSON schemas for each topic payload.
   - Validate payload fields on both app and gateway sides.

## 15) Final Summary

This project is already a strong full-stack IoT implementation combining:

- modern Flutter UI,
- Firebase user/state backend,
- secure MQTT real-time messaging,
- and an efficient ESP32 gateway + ESP-NOW edge mesh pattern.

The gateway-centered architecture is the key design strength: it minimizes cloud complexity for peripheral nodes while preserving real-time control and telemetry to the dashboard.

Recent evolution has focused on operational reliability:

- Display-oriented live sensor ingestion with Firebase Realtime Database.
- Robust garage automation and command delivery behavior.
- Practical, field-calibrated smoke/soil behavior in garden firmware.

## 5.7 Voice Command Cross-Browser Support

### Current State
- The dashboard supports voice commands using browser-based speech recognition (Web Speech API) via the `speech_to_text` Flutter plugin.
- Native speech recognition is only available in browsers that implement the Web Speech API (currently Chrome and Edge).
- On unsupported browsers (such as Firefox and Safari), native voice recognition is not available and the mic button will not function.

### Universal Browser Support (Recommended Approach)
- To enable voice commands in all browsers, integrate a cloud speech-to-text API (such as Google Cloud Speech-to-Text, Azure Speech, or AssemblyAI).
- The app can record audio in any browser (using the standard MediaRecorder API), send the audio to the cloud API, and receive the transcribed text for command execution.
- This approach requires an API key, may incur costs, and introduces a small delay for network round-trip.
- For privacy and cost control, only short command phrases should be sent.

### Implementation Notes
- The current codebase is structured to allow this upgrade: replace the speech recognition logic in `home_screen.dart` with a cloud-based solution.
- If universal browser support is required, add a new service for audio recording and cloud transcription, and update the mic button logic to use it on unsupported browsers.
- Always inform users if their browser does not support native voice recognition and provide clear feedback or fallback options.

### Summary
- Out-of-the-box, voice commands work in Chrome and Edge.
- For all-browser support, a cloud speech-to-text integration is required.
- The project is ready for this upgrade if desired.
