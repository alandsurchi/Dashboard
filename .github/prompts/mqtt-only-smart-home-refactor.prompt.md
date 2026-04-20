---
name: "MQTT-Only Smart Home Refactor"
description: "Complete technical audit and refactor from Firebase to MQTT-only real-time architecture for ESP32 + Flutter"
argument-hint: "Optional: provide EMQX username/password, CA cert file path, and environment names"
agent: "agent"
model: "GPT-5 (copilot)"
---

You are a senior IoT + Flutter + backend engineer with deep expertise in real-time systems.

Perform a complete technical audit and refactor of this smart home system project.

## Objective

Remove all Firebase usage and replace it with a fully functional MQTT-only real-time system that ensures:

- Instant device control (no noticeable delay)
- Stable bidirectional communication
- Clean, scalable architecture

## System Context

This workspace contains:

- ESP32-based devices (lights, fan, servo, etc.)
- Flutter dashboard app (UI + control logic)
- Legacy Firebase integration that must be removed completely

Firebase must not be reintroduced in any form.

## MQTT Broker Details (Use Exactly)

- Broker host: `tf897ef8.ala.dedicated.aws.emqxcloud.com`
- Ports:
  - TCP: `1883`
  - TLS/SSL: `8883`
  - WebSocket: `8083`
  - WebSocket Secure: `8084`

You must choose the best transport per client and justify it:

- ESP32: TCP vs TLS (prefer TLS unless constrained)
- Flutter Android/iOS: TCP or TLS on 1883/8883 (prefer TLS)
- Flutter Web: WebSocket Secure on 8084

## Security Requirements

- Create and use broker authentication (username/password) in EMQX
- Include exact, click-by-click EMQX setup steps for username/password creation and permission assignment
- If TLS is used:
  - Explain certificate chain requirements
   - Show exactly how to configure certificates in ESP32 code
   - Show exactly how to configure certificates in Flutter Android/iOS and Flutter Web
   - If a CA certificate file path/content is provided, integrate it directly into code and assets
   - If the certificate is not provided, include exact manual integration instructions
- Clearly separate automated changes from manual steps

## Required Tasks (Do Not Skip)

1. Full project analysis:
   - Analyze architecture and data flow
   - Identify every Firebase dependency in Flutter and ESP32 code
   - Produce a precise file-by-file Firebase usage inventory
2. Complete Firebase removal:
   - Remove Firebase packages, imports, services, calls, auth, and config
   - Ensure no Firebase references remain in code or configuration
3. MQTT architecture design:
   - Define a production topic taxonomy with control and state topics
   - Define naming conventions, device grouping, and scalability strategy
   - Use structured namespace rooted at `home/main/...`
   - Include examples such as `home/main/light1/set` and `home/main/light1/status`
   - Include QoS/retain policy and payload schema
   - Use JSON payload format for all messages
4. ESP32 implementation:
   - Replace Firebase logic with MQTT client logic
   - Implement connect, subscribe, publish, auto-reconnect, and Wi-Fi resilience
   - Use QoS 1 and retained state messages
   - Configure Last Will message for offline detection
   - Use status topics as command confirmation and support optional ack topics
   - Keep code non-blocking and production-ready
5. Flutter implementation:
   - Integrate `mqtt_client`
   - Implement robust connection lifecycle and auto-reconnect
   - Subscribe to state topics and publish control commands
   - Support Android, iOS, and Web targets
   - Use status topics as primary confirmation and optional ack handling for reliability
   - Ensure immediate UI sync from incoming messages
   - Keep architecture clean and maintainable
6. Real-time sync flow:
   - Implement and verify end-to-end flow: Flutter -> MQTT -> ESP32 -> MQTT -> Flutter
   - Prevent duplicate handling and UI/device desync
7. Performance optimization:
   - Minimize latency and unnecessary traffic
   - Ensure efficient parsing, batching/debouncing where needed
8. Error handling:
   - Recover from broker disconnects, Wi-Fi loss, and invalid payloads
   - Add clear logging and fallback behavior
9. Testing plan:
   - Provide step-by-step validation for control, sync, and reconnect scenarios
   - Include expected outcomes and troubleshooting checks
10. Manual tasks:
   - List anything that must be done manually (broker setup, cert handling, credentials)
   - Provide exact click/path/paste style instructions where applicable

## Strict Constraints

- MQTT is the only communication architecture
- Do not propose Firebase or mixed architectures
- Keep design clean, scalable, and production-grade
- Publish retained messages on all status topics
- Configure Last Will and Testament for online/offline presence
- Use JSON payloads consistently for commands, status, and optional acknowledgments

## Execution Rules

- Work directly on the existing workspace files
- Make concrete code/config changes, not just recommendations
- After edits, verify references and dependencies are consistent
- Call out any blockers explicitly with exact missing inputs

## Output Format (Required)

Return results in this exact section order:

1. Architecture diagram (ASCII/mermaid text)
2. Firebase dependency inventory (file-by-file)
3. Topic structure and payload schema
4. ESP32 refactor summary + key code changes
5. Flutter refactor summary + key code changes
6. EMQX authentication setup guide (username/password)
7. Security and TLS certificate integration steps
8. Real-time sync guarantees (dedupe/desync prevention)
9. Performance optimizations applied
10. Error handling and recovery strategy
11. Testing checklist and step-by-step test procedure
12. Manual tasks required from the user
13. Final verification checklist confirming no Firebase remains

## Optional Inputs

If provided by the user, incorporate these:

- MQTT username/password
- CA certificate file path/content
- Client certificate/key (if mutual TLS is required)
- Environment name (for scalable namespace, for example home/main)
- Device/topic naming preferences