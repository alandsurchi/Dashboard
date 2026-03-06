import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

class MqttService extends ChangeNotifier {
  // EMQX Cloud Variables
  final String _server = 'wss://i2022f00.ala.eu-central-1.emqxsl.com/mqtt';
  late final int _port;
  final String _username = 'flutter_app';
  final String _password = 'Smart1Eco.'; 
  
  MqttBrowserClient? _client;
  bool _isConnected = false;
  Function(String topic, String payload)? onMessageReceived;

  bool get isConnected => _isConnected;

  MqttService({int port = 8084}) {
    _port = port;
  }

  // Connect to the broker
  Future<void> connect(String uid) async {
    // Generate a unique client ID avoiding conflicts
    final clientId = 'flutter_dash_${DateTime.now().millisecondsSinceEpoch}';
    
    // Use MqttBrowserClient for Flutter Web WebSockets
    _client = MqttBrowserClient(_server, clientId);
    _client!.port = _port;
    _client!.logging(on: true); 

    // Set callbacks
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    
    // Connection Message
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('home/$uid/status') // Notification when disconnected ungracefully
        .withWillMessage('{"status": "offline"}')
        .startClean() // Important for fresh sessions
        .withWillQos(MqttQos.atLeastOnce);

    // Provide Auth Username/Password
    connMess.authenticateAs(_username, _password);
    _client!.connectionMessage = connMess;

    try {
      if (kDebugMode) {
        print('MQTT Service: Attempting to connect to EMQX Cloud...');
      }
      await _client!.connect();
    } on Exception catch (e) {
      if (kDebugMode) {
        print('MQTT Service: Error connecting = $e');
      }
      disconnect();
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      notifyListeners();
      
      // Subscribe to all status topics the dashboard needs
      _client!.subscribe('home/$uid/home_sensors/status', MqttQos.atLeastOnce);
      _client!.subscribe('home/$uid/garage_door/status', MqttQos.atLeastOnce);
      
      _setupListeners(uid);
    } else {
      if (kDebugMode) {
        print('MQTT Service: ERROR connecting status is ${_client!.connectionStatus!.state}');
      }
      disconnect();
    }
  }

  // Listen to incoming messages from the ESP32 (e.g. status updates)
  void _setupListeners(String uid) {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      if (kDebugMode) {
        print('MQTT Service: Received message: topic is <${c[0].topic}>, payload is <-- $pt -->');
        print('');
      }
      
      // Pass the message up to the DashboardState
      if (onMessageReceived != null) {
        onMessageReceived!(c[0].topic, pt);
      }
    });
  }

  // Publish a command to the ESP32
  void publishCommand(String uid, String deviceId, Map<String, dynamic> command) {
    if (_client == null || _client!.connectionStatus!.state != MqttConnectionState.connected) {
      if (kDebugMode) {
        print('MQTT Service: Cannot publish. Client is not connected.');
      }
      return;
    }

    final topic = 'home/$uid/$deviceId/command';
    final payloadStore = MqttClientPayloadBuilder();
    
    // Parse the dart Map into a JSON String for the ESP32 to read
    final String jsonCommand = jsonEncode(command); 
    payloadStore.addString(jsonCommand);

    if (kDebugMode) {
       print('MQTT Service: Publishing to topic `$topic` with payload `$jsonCommand`');
    }

    _client!.publishMessage(topic, MqttQos.atLeastOnce, payloadStore.payload!);
  }

  void disconnect() {
    if (kDebugMode) {
      print('MQTT Service: Disconnecting');
    }
    _client?.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  // Callbacks
  void _onConnected() {
    if (kDebugMode) {
      print('MQTT Service: Connected to EMQX!');
    }
  }

  void _onDisconnected() {
    if (kDebugMode) {
      print('MQTT Service: Disconnected from EMQX!');
    }
    _isConnected = false;
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    if (kDebugMode) {
      print('MQTT Service: Subscribed to topic $topic');
    }
  }
}
