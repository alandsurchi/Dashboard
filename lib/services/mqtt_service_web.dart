import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

class MqttService extends ChangeNotifier {
  static const String _wssEndpoint = 'wss://tf897ef8.ala.dedicated.aws.emqxcloud.com/mqtt';
  static const int _brokerPort = 8084;
  static const String _topicRoot = 'home/main';

  static const String _username = String.fromEnvironment('MQTT_USERNAME', defaultValue: 'Flutter');
  static const String _password = String.fromEnvironment('MQTT_PASSWORD', defaultValue: '123');

  MqttBrowserClient? _client;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _lastContext = 'main';

  Function(String topic, String payload)? onMessageReceived;

  bool get isConnected => _isConnected;

  Future<void> connect(String uid) async {
    _lastContext = uid;
    if (_isConnecting || _isConnected) {
      return;
    }

    _isConnecting = true;

    final clientId = 'flutter_web_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttBrowserClient(_wssEndpoint, clientId)
      ..port = _brokerPort
      ..keepAlivePeriod = 20
      ..autoReconnect = false
      ..logging(on: kDebugMode)
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onSubscribed = _onSubscribed;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(_username, _password)
        .withWillTopic('$_topicRoot/dashboard/status')
        .withWillMessage(jsonEncode({
          'online': false,
          'client': clientId,
          'source': 'flutter_web',
        }))
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();

    _client = client;

    try {
      await _client!.connect();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MQTT web connect error: $e');
      }
      _setDisconnectedState();
      _scheduleReconnect();
      _isConnecting = false;
      return;
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected = true;
      notifyListeners();

      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _client!.subscribe('$_topicRoot/+/status', MqttQos.atLeastOnce);
      _client!.subscribe('$_topicRoot/+/ack', MqttQos.atLeastOnce);
      _publishPresence(online: true);
      _setupListeners();
    } else {
      _setDisconnectedState();
      _scheduleReconnect();
    }

    _isConnecting = false;
  }

  void _setupListeners() {
    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final message in messages) {
        final payload = message.payload as MqttPublishMessage;
        final text = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
        onMessageReceived?.call(message.topic, text);
      }
    });
  }

  void publishCommand(String uid, String deviceId, Map<String, dynamic> command) {
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) {
      if (kDebugMode) {
        debugPrint('MQTT web publish skipped, client is disconnected');
      }
      return;
    }

    final payload = MqttClientPayloadBuilder();
    payload.addString(jsonEncode({...command, 'ts': DateTime.now().toUtc().toIso8601String()}));
    client.publishMessage('$_topicRoot/$deviceId/set', MqttQos.atLeastOnce, payload.payload!);
  }

  void _publishPresence({required bool online}) {
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    final payload = MqttClientPayloadBuilder();
    payload.addString(jsonEncode({
      'online': online,
      'source': 'flutter_web',
      'context': _lastContext,
      'ts': DateTime.now().toUtc().toIso8601String(),
    }));

    client.publishMessage(
      '$_topicRoot/dashboard/status',
      MqttQos.atLeastOnce,
      payload.payload!,
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _publishPresence(online: false);
    _client?.disconnect();
    _setDisconnectedState();
  }

  void _onConnected() {
    if (kDebugMode) {
      debugPrint('MQTT web connected to $_wssEndpoint');
    }
  }

  void _onDisconnected() {
    _setDisconnectedState();
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    if (kDebugMode) {
      debugPrint('MQTT web subscribed: $topic');
    }
  }

  void _setDisconnectedState() {
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    } else {
      _isConnected = false;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected || _isConnecting) {
        return;
      }
      connect(_lastContext);
    });
  }
}
