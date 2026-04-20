# MQTT TLS + EMQX Authentication Setup

This project now uses MQTT with TLS and topic namespace `home/main`.

## 1) EMQX Username/Password Setup

1. Open EMQX Cloud console.
2. Open your deployment.
3. Go to Access Control.
4. Open Authentication.
5. Click Create Authentication.
6. Choose Password-Based.
7. Choose Built-in Database.
8. Save.
9. Open Users for that authenticator.
10. Click Add User.
11. Enter username and a strong password.
12. Save.

## 2) EMQX Authorization (ACL) Setup

1. In Access Control, open Authorization.
2. Enable authorization if disabled.
3. Add allow rules for Flutter client:
   - Publish: home/main/+/set
   - Publish: home/main/dashboard/status
   - Subscribe: home/main/+/status
   - Subscribe: home/main/+/ack
4. Add allow rules for ESP32 gateway client:
   - Subscribe: home/main/+/set
   - Subscribe: home/main/+/command
   - Publish: home/main/+/status
   - Publish: home/main/+/ack
   - Publish: home/main/gateway/status
5. Keep deny as final fallback.

## 3) TLS Certificate Integration Status

The CA certificate is integrated in two places:

- Flutter mobile loads `emqxcloud-ca.crt` asset for TLS trust.
- ESP32 uses `setCACert(...)` with the CA certificate embedded.

For Flutter Web, TLS trust is handled by the browser trust store using WSS (port 8084).

## 4) Configure Credentials In Code/Run

### ESP32

Edit these constants in `esp32_code/Home_Control/Home_Control.ino`:

- mqtt_user
- mqtt_password

### Flutter Android/iOS/Web

Pass credentials at run/build time using Dart defines:

flutter run --dart-define=MQTT_USERNAME=YOUR_USER --dart-define=MQTT_PASSWORD=YOUR_PASS

For web:

flutter run -d chrome --dart-define=MQTT_USERNAME=YOUR_USER --dart-define=MQTT_PASSWORD=YOUR_PASS

For release builds, use the same dart-define flags in build commands.

## 5) Validation Checklist

1. Start Flutter with valid MQTT_USERNAME and MQTT_PASSWORD.
2. Flash ESP32 with valid mqtt_user and mqtt_password.
3. Confirm EMQX client list shows both clients connected.
4. Publish a command from Flutter and confirm:
   - Device acts immediately.
   - Status topic updates.
   - Optional ack topic updates.
5. Disconnect ESP32 power and verify LWT/offline state appears.
6. Reconnect ESP32 and verify auto-reconnect and online status publication.
