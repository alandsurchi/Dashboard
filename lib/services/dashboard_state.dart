import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'mqtt_service.dart';

class DeviceSchedule {
  final String deviceName;
  final TimeOfDay? onTime;
  final TimeOfDay? offTime;
  DeviceSchedule({required this.deviceName, this.onTime, this.offTime});
}

class _RealtimeSensorSnapshot {
  final double? temperature;
  final int? humidity;
  final bool? motionDetected;
  final String? smokeLevel;
  final double? soilMoisture;
  final double? tankLevel;

  const _RealtimeSensorSnapshot({
    this.temperature,
    this.humidity,
    this.motionDetected,
    this.smokeLevel,
    this.soilMoisture,
    this.tankLevel,
  });

  bool get hasAnyData =>
      temperature != null ||
      humidity != null ||
      motionDetected != null ||
      smokeLevel != null ||
      soilMoisture != null ||
      tankLevel != null;
}

class DashboardState extends ChangeNotifier {
  static const String _rtdbUrl = String.fromEnvironment(
    'RTDB_URL',
    defaultValue: 'https://smarteco-8d700-default-rtdb.europe-west1.firebasedatabase.app/',
  );
  static const String _rtdbSensorPathTemplate = String.fromEnvironment(
    'RTDB_SENSOR_PATH',
    defaultValue: '/',
  );

  AuthService? auth;
  FirestoreService? firestore;
  MqttService? mqtt;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _rtdbUrl,
  );

  /// Called by main.dart's ProxyProvider update callback to refresh service
  /// references without destroying this instance (which would reset all state).
  void updateDependencies(AuthService? newAuth, FirestoreService? newFirestore, MqttService? newMqtt) {
    final bool authChanged = auth != newAuth;
    auth = newAuth;
    firestore = newFirestore;
    mqtt = newMqtt;

    // Only re-initialize cloud services when the auth instance changes
    // (i.e. user logs in / out), not on every MQTT message.
    if (authChanged) {
      _initCloudServices();
    }
  }
  
  StreamSubscription? _deviceSub;
  StreamSubscription<DatabaseEvent>? _rtdbSub;
  bool _rtdbSensorFeedActive = false;
  bool _rtdbHomeTemperatureActive = false;
  bool _rtdbHomeHumidityActive = false;
  bool _rtdbHomeMotionActive = false;
  bool _rtdbSmokeActive = false;
  bool _rtdbSoilActive = false;
  bool _rtdbTankActive = false;

  // === HOME CONTROL STATE ===
  bool led1On = false;
  bool led2On = false;
  bool led3On = false;
  bool rgbOn = false;
  bool fanOn = false;
  bool tvOn = false;
  bool washOn = false;
  Color rgbColor = Colors.blue;
  double rgbBrightness = 1.0;
  double temperature = 24.5;
  int humidity = 55;
  bool hasLiveHomeSensorData = false;
  String doorStatus = 'CLOSED'; 
  List<String> doorLog = ['Door closed at 09:00 AM'];
  bool motionDetected = false;
  String lastMotionTime = '14:25';
  bool nightMode = false;
  int batteryLevel = 82;
  bool solarCharging = true;

  // Clock
  late Timer _clockTimer;
  DateTime currentTime = DateTime.now();
  List<DeviceSchedule> activeSchedules = [];
  String? _lastScheduleMinuteKey;

  // --- GARAGE AUTOMATION ---
  String garageStatus = 'CLOSED'; 
  bool garageCarPresent = false;
  bool garageLocked = false;
  bool garageBluetoothConnected = false;
  
  bool autoOpenGarage = true;
  bool autoCloseGarage = false;
  double autoCloseTimer = 30; 
  List<String> garageLog = [];
  Timer? _autoCloseCountdown;
  DateTime? _lastGarageAutoOpenAttempt;
  static const Duration _garageAutoOpenCooldown = Duration(seconds: 6);
  DateTime? _lastGarageAutoCloseAttempt;
  static const Duration _garageAutoCloseCooldown = Duration(seconds: 6);

  // === GARDEN STATE ===
  double soilMoisture = 45; 
  String smokeLevel = 'NORMAL'; 
  double gardenTemp = 28.0;
  int gardenHumidity = 40;
  double tankLevel = 75; 

  bool gardenPumpRunning = false;
  bool firePumpRunning = false;
  bool autoGardenMode = true; 
  bool systemEnabled = true; 
  String lastWateringTime = '09:32 AM';
  bool autoFireMode = true;
  String? fireAlertTime;

  List<String> gardenLog = [
    '💧 Watered: 09:32 for 10 sec',
    '☀️ Sun exposure high at 08:00',
  ];

  bool _isDisposed = false;

  String _currentTimeLabel() {
    return "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
  }

  void _appendGarageLog(String message) {
    final time = _currentTimeLabel();
    garageLog.insert(0, '$message at $time');
    if (garageLog.length > 20) {
      garageLog.removeLast();
    }
  }

  String _garageStatusLogMessage(String status) {
    switch (status) {
      case 'OPEN':
        return 'Door opened';
      case 'OPENING':
        return 'Door opening';
      case 'CLOSED':
        return 'Door closed';
      case 'CLOSING':
        return 'Door closing';
      default:
        return 'Door status: $status';
    }
  }

  void _evaluateGarageAutoOpen({required String reason}) {
    if (!autoOpenGarage || garageLocked) return;

    final status = garageStatus.toUpperCase();
    final isClosed = status == 'CLOSED' || status == 'CLOSING' || status == 'STOPPED';
    if (!(garageBluetoothConnected && garageCarPresent && isClosed)) return;

    final now = DateTime.now();
    if (_lastGarageAutoOpenAttempt != null &&
        now.difference(_lastGarageAutoOpenAttempt!) < _garageAutoOpenCooldown) {
      return;
    }

    _lastGarageAutoOpenAttempt = now;
    _appendGarageLog('Auto-open triggered ($reason)');
    setGarageDoor(true, source: 'auto mode');
  }

  void _evaluateGarageAutoCloseOnConditionLoss({required String reason}) {
    if (!autoOpenGarage || garageLocked) return;

    final status = garageStatus.toUpperCase();
    final isOpen = status == 'OPEN' || status == 'OPENING';
    if (!isOpen) return;

    if (garageBluetoothConnected && garageCarPresent) return;

    final now = DateTime.now();
    if (_lastGarageAutoCloseAttempt != null &&
        now.difference(_lastGarageAutoCloseAttempt!) < _garageAutoCloseCooldown) {
      return;
    }

    _lastGarageAutoCloseAttempt = now;
    _appendGarageLog('Auto-close triggered ($reason)');
    setGarageDoor(false, source: 'condition lost');
  }

  DashboardState(this.auth, this.firestore, this.mqtt) {
    // Start the clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed) {
        currentTime = DateTime.now();
        _runDeviceSchedules(currentTime);
        notifyListeners();
      }
    });

    _initCloudServices();
  }

  void _initCloudServices() async {
    final uid = auth?.currentUser?.uid;
    if (uid != null) {
      // 1. Connect MQTT Broker
      if (mqtt != null && !mqtt!.isConnected) {
        mqtt!.onMessageReceived = _handleMqttMessage;
        mqtt!.connect(uid);
      }

      // 1.5 Connect Realtime Database live sensor feed (display only)
      _startRealtimeSensorStream(uid);

      // 2. Init Firestore: one-time load only.
      // We do NOT use a continuous stream because every Firestore write
      // (e.g. sensor data from MQTT) would trigger a full-collection
      // snapshot that overwrites optimistic UI updates, making buttons
      // appear to snap back.
      if (firestore != null) {
        await firestore!.initializeDefaultDevices(uid);

        // One-time read to populate initial state
        _deviceSub?.cancel();
        _deviceSub = firestore!.streamDevices(uid).listen((snapshot) {
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            _parseDeviceData(doc.id, data);
          }
          if (!_isDisposed) notifyListeners();
          // Cancel after first snapshot — we only need initial load.
          // All further state changes are handled optimistically in _updateFB.
          _deviceSub?.cancel();
          _deviceSub = null;
        });
      }
    } else {
      _rtdbSub?.cancel();
      _rtdbSub = null;
      _rtdbSensorFeedActive = false;
      _rtdbHomeTemperatureActive = false;
      _rtdbHomeHumidityActive = false;
      _rtdbHomeMotionActive = false;
      _rtdbSmokeActive = false;
      _rtdbSoilActive = false;
      _rtdbTankActive = false;
      hasLiveHomeSensorData = false;
    }
  }

  void _startRealtimeSensorStream(String uid) {
    final resolvedPath = _resolveRtdbPath(uid);
    final ref = resolvedPath.isEmpty ? _rtdb.ref() : _rtdb.ref(resolvedPath);

    _rtdbSub?.cancel();
    _rtdbSub = ref.onValue.listen(
      (event) {
        final payload = event.snapshot.value;
        if (payload == null) return;

        final sensorData = _extractRealtimeSensorSnapshot(payload);
        if (!sensorData.hasAnyData) return;

        bool changed = false;

        if (sensorData.temperature != null && temperature != sensorData.temperature) {
          temperature = sensorData.temperature!;
          gardenTemp = sensorData.temperature!;
          changed = true;
        }
        if (sensorData.temperature != null) {
          _rtdbHomeTemperatureActive = true;
        }
        if (sensorData.humidity != null && humidity != sensorData.humidity) {
          humidity = sensorData.humidity!;
          gardenHumidity = sensorData.humidity!;
          changed = true;
        }
        if (sensorData.humidity != null) {
          _rtdbHomeHumidityActive = true;
        }
        if (sensorData.motionDetected != null && motionDetected != sensorData.motionDetected) {
          motionDetected = sensorData.motionDetected!;
          if (motionDetected) {
            final now = DateTime.now();
            lastMotionTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          }
          changed = true;
        }
        if (sensorData.motionDetected != null) {
          _rtdbHomeMotionActive = true;
        }

        if (sensorData.smokeLevel != null && smokeLevel != sensorData.smokeLevel) {
          smokeLevel = sensorData.smokeLevel!;
          changed = true;
        }
        if (sensorData.smokeLevel != null) {
          _rtdbSmokeActive = true;
        }
        if (sensorData.soilMoisture != null && soilMoisture != sensorData.soilMoisture) {
          soilMoisture = sensorData.soilMoisture!;
          changed = true;
        }
        if (sensorData.soilMoisture != null) {
          _rtdbSoilActive = true;
        }
        if (sensorData.tankLevel != null && tankLevel != sensorData.tankLevel) {
          tankLevel = sensorData.tankLevel!;
          changed = true;
        }
        if (sensorData.tankLevel != null) {
          _rtdbTankActive = true;
        }

        if (sensorData.temperature != null ||
            sensorData.humidity != null ||
            sensorData.motionDetected != null) {
          hasLiveHomeSensorData = true;
        }
        _rtdbSensorFeedActive = true;

        if (changed && !_isDisposed) {
          notifyListeners();
        }
      },
      onError: (Object e) {
        debugPrint('RTDB sensor stream error: $e');
      },
    );
  }

  String _resolveRtdbPath(String uid) {
    final trimmed = _rtdbSensorPathTemplate.trim();
    if (trimmed.isEmpty || trimmed == '/' || trimmed == '.') return '';

    final withUid = trimmed.replaceAll('{uid}', uid);
    return withUid.startsWith('/') ? withUid.substring(1) : withUid;
  }

  _RealtimeSensorSnapshot _extractRealtimeSensorSnapshot(dynamic root) {
    final tempRaw = _findValueByKeys(root, const {
      'temperature',
      'temp',
      'hometemperature',
      'hometemp'
    });
    final humidityRaw = _findValueByKeys(root, const {
      'humidity',
      'hum',
      'homehumidity',
      'homehum'
    });
    final motionRaw = _findValueByKeys(root, const {
      'motiondetected',
      'motion',
      'pir',
      'pirmotion'
    });
    final smokeRaw = _findValueByKeys(root, const {
      'smokelevel',
      'smoke',
      'mq2'
    });
    final soilRaw = _findValueByKeys(root, const {
      'soilmoisture',
      'soil',
      'moisture'
    });
    final tankRaw = _findValueByKeys(root, const {
      'tanklevel',
      'waterlevel',
      'tank',
      'water'
    });

    return _RealtimeSensorSnapshot(
      temperature: _toDouble(tempRaw),
      humidity: _toInt(humidityRaw),
      motionDetected: _toBool(motionRaw),
      smokeLevel: _toSmokeLevel(smokeRaw),
      soilMoisture: _toDouble(soilRaw),
      tankLevel: _toDouble(tankRaw),
    );
  }

  dynamic _findValueByKeys(dynamic node, Set<String> desiredKeys) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (desiredKeys.contains(key)) {
          return entry.value;
        }
      }
      for (final value in node.values) {
        final found = _findValueByKeys(value, desiredKeys);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findValueByKeys(item, desiredKeys);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _normalizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final s = value.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'on' || s == 'high') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'off' || s == 'low' || s == 'normal') return false;
    return null;
  }

  String? _toSmokeLevel(dynamic value) {
    if (value == null) return null;
    if (value is num) return value > 0 ? 'HIGH' : 'NORMAL';

    final s = value.toString().trim().toUpperCase();
    if (s.isEmpty) return null;
    if (s == '1' || s == 'TRUE' || s == 'HIGH' || s == 'ALERT') return 'HIGH';
    if (s == '0' || s == 'FALSE' || s == 'NORMAL' || s == 'LOW' || s == 'CLEAR') return 'NORMAL';
    return s;
  }

  void _handleMqttMessage(String topic, String payload) {
    try {
      if (topic.endsWith('/home_sensors/status')) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (!_rtdbHomeTemperatureActive || !_rtdbHomeHumidityActive || !_rtdbHomeMotionActive) {
          hasLiveHomeSensorData = true;
        }
        
        bool changed = false;
        if (!_rtdbHomeTemperatureActive && data.containsKey('temperature')) {
          final raw = data['temperature'];
          final parsed = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
          if (parsed != null) {
            temperature = parsed;
            gardenTemp = parsed;
            changed = true;
          }
        }
        if (!_rtdbHomeHumidityActive && data.containsKey('humidity')) {
          final raw = data['humidity'];
          final parsed = raw is num ? raw.toInt() : int.tryParse(raw.toString());
          if (parsed != null) {
            humidity = parsed;
            gardenHumidity = parsed;
            changed = true;
          }
        }
        if (!_rtdbHomeMotionActive && data.containsKey('motionDetected')) {
          final bool? parsedMotion = _toBool(data['motionDetected']);
          if (parsedMotion != null) {
            bool newMotion = parsedMotion;
            if (newMotion != motionDetected) {
              motionDetected = newMotion;
              if (newMotion) {
                lastMotionTime = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
              }
              changed = true;
            }
          }
        }
        
        if (changed && !_isDisposed) {
          notifyListeners();
          
          // Optionally, sync to Firestore so it persists across reloads
          final uid = auth?.currentUser?.uid;
          if (uid != null && firestore != null) {
            firestore!.updateDeviceState(uid, 'home_sensors', {
              'temperature': temperature,
              'humidity': humidity,
              'motionDetected': motionDetected,
            });
          }
        }
      } 
      else if (topic.endsWith('/garage_door/status')) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        bool changed = false;

        final dynamic statusValue =
            data.containsKey('status') ? data['status'] : data['doorStatus'];
        if (statusValue != null) {
          final newStatus = statusValue.toString().toUpperCase();
          if (garageStatus != newStatus) {
            garageStatus = newStatus;
            _appendGarageLog(_garageStatusLogMessage(newStatus));
            changed = true;
          }
        }

        final dynamic carRaw =
            data.containsKey('carPresent') ? data['carPresent'] : data['carDetected'];
        final bool? carParsed = _toBool(carRaw);
        if (carParsed != null && garageCarPresent != carParsed) {
          garageCarPresent = carParsed;
          _appendGarageLog(carParsed ? 'Ultrasonic detected a car' : 'Ultrasonic: no car detected');
          changed = true;
        }

        final dynamic bleRaw = data.containsKey('bluetoothConnected')
            ? data['bluetoothConnected']
            : (data.containsKey('bleConnected') ? data['bleConnected'] : data['bluetooth']);
        final bool? bleParsed = _toBool(bleRaw);
        if (bleParsed != null && garageBluetoothConnected != bleParsed) {
          garageBluetoothConnected = bleParsed;
          _appendGarageLog(bleParsed ? 'Bluetooth connected' : 'Bluetooth disconnected');
          changed = true;
        }

        _evaluateGarageAutoOpen(reason: 'bluetooth + ultrasonic');
        _evaluateGarageAutoCloseOnConditionLoss(reason: 'condition lost');

        if (changed && !_isDisposed) {
          notifyListeners();
        }
      }
      else if (topic.endsWith('/garden_sensors/status') || topic.endsWith('/garden_controls/status')) {
        final data = Map<String, dynamic>.from(jsonDecode(payload) as Map<String, dynamic>);

        if (_rtdbSensorFeedActive && topic.endsWith('/garden_sensors/status')) {
          if (_rtdbSoilActive) data.remove('soilMoisture');
          if (_rtdbSmokeActive) data.remove('smokeLevel');
          if (_rtdbTankActive) data.remove('tankLevel');
          if (_rtdbHomeTemperatureActive) data.remove('gardenTemp');
          if (_rtdbHomeHumidityActive) data.remove('gardenHumidity');
        }

        // Use the common parser for these documents
        final docId = topic.contains('sensors') ? 'garden_sensors' : 'garden_controls';
        _parseDeviceData(docId, data);
        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      debugPrint("Error parsing MQTT payload: $e");
    }
  }

  // Only update fields that are explicitly present in the partial data map.
  // Using ?? with absent keys would reset unrelated sibling fields to defaults
  // when, e.g., toggleGardenPump sends only {'gardenPumpRunning': true}.
  void _parseDeviceData(String id, Map<String, dynamic> data) {
    switch (id) {
      case 'led1': if (data.containsKey('state')) led1On = data['state']; break;
      case 'led2': if (data.containsKey('state')) led2On = data['state']; break;
      case 'led3': if (data.containsKey('state')) led3On = data['state']; break;
      case 'fan':  if (data.containsKey('state')) fanOn  = data['state']; break;
      case 'tv':   if (data.containsKey('state')) tvOn   = data['state']; break;
      case 'wash': if (data.containsKey('state')) washOn = data['state']; break;
      case 'rgb':
        if (data.containsKey('state'))      rgbOn        = data['state'];
        if (data.containsKey('brightness')) rgbBrightness = (data['brightness'] as num).toDouble();
        if (data.containsKey('r') && data.containsKey('g') && data.containsKey('b')) {
          rgbColor = Color.fromRGBO(data['r'], data['g'], data['b'], 1.0);
        }
        break;
      case 'home_sensors':
        if (data.containsKey('temperature')) {
          final parsed = _toDouble(data['temperature']);
          if (parsed != null) {
            temperature = parsed;
            gardenTemp = parsed;
          }
        }
        if (data.containsKey('humidity')) {
          final parsed = _toInt(data['humidity']);
          if (parsed != null) {
            humidity = parsed;
            gardenHumidity = parsed;
          }
        }
        if (data.containsKey('motionDetected')) {
          final parsed = _toBool(data['motionDetected']);
          if (parsed != null) {
            motionDetected = parsed;
          }
        }
        break;
      case 'door':
        if (data.containsKey('status')) doorStatus = data['status'];
        break;
      case 'garage_door':
        if (data.containsKey('status')) {
          garageStatus = data['status'].toString().toUpperCase();
        }
        if (data.containsKey('carPresent')) {
          final parsed = _toBool(data['carPresent']);
          if (parsed != null) garageCarPresent = parsed;
        }
        if (data.containsKey('bluetoothConnected')) {
          final parsed = _toBool(data['bluetoothConnected']);
          if (parsed != null) garageBluetoothConnected = parsed;
        }
        if (data.containsKey('locked')) {
          final parsed = _toBool(data['locked']);
          if (parsed != null) garageLocked = parsed;
        }
        break;
      case 'garage_settings':
        if (data.containsKey('autoOpen')) {
          final parsed = _toBool(data['autoOpen']);
          if (parsed != null) autoOpenGarage = parsed;
        }
        if (data.containsKey('autoClose')) {
          final parsed = _toBool(data['autoClose']);
          if (parsed != null) autoCloseGarage = parsed;
        }
        if (data.containsKey('autoCloseTimer')) {
          final parsed = _toDouble(data['autoCloseTimer']);
          if (parsed != null) autoCloseTimer = parsed;
        }
        break;
      case 'garden_sensors':
        if (data.containsKey('soilMoisture')) {
          final parsed = _toDouble(data['soilMoisture']);
          if (parsed != null) soilMoisture = parsed;
        }
        if (data.containsKey('smokeLevel')) {
          final parsed = _toSmokeLevel(data['smokeLevel']);
          if (parsed != null) smokeLevel = parsed;
        }
        if (data.containsKey('gardenTemp')) {
          final parsed = _toDouble(data['gardenTemp']);
          if (parsed != null) gardenTemp = parsed;
        }
        if (data.containsKey('gardenHumidity')) {
          final parsed = _toInt(data['gardenHumidity']);
          if (parsed != null) gardenHumidity = parsed;
        }
        if (data.containsKey('tankLevel')) {
          final parsed = _toDouble(data['tankLevel']);
          if (parsed != null) tankLevel = parsed;
        }
        break;
      case 'garden_controls':
        if (data.containsKey('gardenPumpRunning')) gardenPumpRunning = data['gardenPumpRunning'];
        if (data.containsKey('firePumpRunning'))   firePumpRunning   = data['firePumpRunning'];
        if (data.containsKey('autoGardenMode'))    autoGardenMode    = data['autoGardenMode'];
        if (data.containsKey('autoFireMode'))      autoFireMode      = data['autoFireMode'];
        if (data.containsKey('systemEnabled'))     systemEnabled     = data['systemEnabled'];
        break;
    }
  }

  void _updateFB(String docId, Map<String, dynamic> data) {
    final uid = auth?.currentUser?.uid;
    if (uid == null) {
      debugPrint('🔴 _updateFB: UID is null — action blocked.');
      return;
    }

    // 1. Optimistic local update — instant UI response
    _parseDeviceData(docId, data);
    if (!_isDisposed) notifyListeners();

    // 2. Fire-and-forget Firestore write (don't await — avoids blocking on permission errors)
    if (firestore != null) {
      firestore!.updateDeviceState(uid, docId, data).catchError((e) {
        debugPrint('🔴 Firestore write failed for $docId: $e');
      });
    }

    // 3. Real-time MQTT command to ESP32
    if (mqtt != null && mqtt!.isConnected) {
      mqtt!.publishCommand(uid, docId, data);
    }
  }


  @override
  void dispose() {
    _isDisposed = true;
    _clockTimer.cancel();
    _autoCloseCountdown?.cancel();
    _deviceSub?.cancel();
    _rtdbSub?.cancel();
    if (mqtt?.onMessageReceived == _handleMqttMessage) {
      mqtt?.onMessageReceived = null;
    }
    super.dispose();
  }

  // --- HOME ACTIONS ---
  void toggleLed1(bool val) => _updateFB('led1', {'state': val});
  void toggleLed2(bool val) => _updateFB('led2', {'state': val});
  void toggleLed3(bool val) => _updateFB('led3', {'state': val});
  void toggleFan(bool val) => _updateFB('fan', {'state': val});
  void toggleTv(bool val) => _updateFB('tv', {'state': val});
  void toggleWash(bool val) => _updateFB('wash', {'state': val});
  
  void toggleRgb(bool val) => _updateFB('rgb', {
    'state': val, 
    'r': rgbColor.red, 
    'g': rgbColor.green, 
    'b': rgbColor.blue,
    'brightness': rgbBrightness
  });
  
  void setRgbColor(Color c) { 
    rgbColor = c; 
    _updateFB('rgb', {
      'state': rgbOn,
      'r': c.red,
      'g': c.green,
      'b': c.blue,
      'brightness': rgbBrightness
    });
  } 
  
  void setRgbBrightness(double b) {
    rgbBrightness = b;
    _updateFB('rgb', {
      'state': rgbOn,
      'r': rgbColor.red,
      'g': rgbColor.green,
      'b': rgbColor.blue,
      'brightness': b
    });
  }

  void setDoor(String status) {
    if (nightMode) return;
    String time = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
    doorLog.insert(0, 'Door ${status.toLowerCase()} at $time');
    if (doorLog.length > 5) doorLog.removeLast();
    
    // ESP32 expects boolean state: {"state": true/false}
    bool isOpen = status == 'OPEN';
    _updateFB('door', {
      'status': status,
      'state': isOpen 
    });
  }

  void toggleNightMode(bool val) {
    nightMode = val;
    if (nightMode) {
      toggleLed1(false); toggleLed2(false); toggleLed3(false); toggleRgb(false); toggleTv(false); toggleWash(false);
    }
    notifyListeners();
  }

  void clearMotion() {
    motionDetected = false;
    _updateFB('home_sensors', {
       'motionDetected': false,
       'temperature': temperature,
       'humidity': humidity
    });
    notifyListeners();
  }

  void addSchedule(DeviceSchedule schedule) {
    activeSchedules.add(schedule);
    notifyListeners();
  }

  void removeSchedule(DeviceSchedule schedule) {
    activeSchedules.remove(schedule);
    notifyListeners();
  }

  void _runDeviceSchedules(DateTime now) {
    if (activeSchedules.isEmpty) return;

    final minuteKey = '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
    if (_lastScheduleMinuteKey == minuteKey) return;
    _lastScheduleMinuteKey = minuteKey;

    for (final schedule in List<DeviceSchedule>.from(activeSchedules)) {
      if (_matchesScheduleMinute(schedule.onTime, now)) {
        _applyScheduledAction(schedule.deviceName, true);
      }
      if (_matchesScheduleMinute(schedule.offTime, now)) {
        _applyScheduledAction(schedule.deviceName, false);
      }
    }
  }

  bool _matchesScheduleMinute(TimeOfDay? time, DateTime now) {
    return time != null && time.hour == now.hour && time.minute == now.minute;
  }

  void _applyScheduledAction(String deviceName, bool turnOn) {
    switch (deviceName) {
      case 'LED 1':
        toggleLed1(turnOn);
        break;
      case 'LED 2':
        toggleLed2(turnOn);
        break;
      case 'LED 3':
        toggleLed3(turnOn);
        break;
      case 'RGB Light':
        toggleRgb(turnOn);
        break;
      case 'Fan':
        toggleFan(turnOn);
        break;
      case 'TV':
        toggleTv(turnOn);
        break;
      case 'Washing Machine':
        toggleWash(turnOn);
        break;
      case 'Garden Pump':
        toggleGardenPump(turnOn);
        break;
      case 'Fire Pump':
        toggleFirePump(turnOn);
        break;
      default:
        break;
    }
  }

  void _updateLogs(String logName, String message) {
    String time = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
    if (logName == 'doorLog') {
      doorLog.insert(0, '$message at $time');
      if (doorLog.length > 5) doorLog.removeLast();
    } else if (logName == 'garageLog') {
      garageLog.insert(0, '$message at $time');
      if (garageLog.length > 5) garageLog.removeLast();
    }
  }

  void setGarageDoor(bool open, {String source = 'remote'}) {
    String newStatus = open ? 'OPEN' : 'CLOSED';
    _appendGarageLog(open ? 'Open command sent ($source)' : 'Close command sent ($source)');
    
    // Exactly matches the home control setDoor logic
    _updateFB('garage_door', {
      'status': newStatus,
      'state': open 
    });
  }

  // --- GARAGE ACTIONS ---
  void setGarageStatus(String status) {
    if (garageLocked && (status == 'OPEN' || status == 'OPENING')) return;
    
    String time = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
    if (status == 'OPEN') {
      garageLog.insert(0, 'Garage opened at $time');
      if (autoCloseGarage && !garageCarPresent) _startAutoCloseTimer();
    } else if (status == 'CLOSED') {
      garageLog.insert(0, 'Garage closed at $time');
      _autoCloseCountdown?.cancel();
    }
    if (garageLog.length > 5) garageLog.removeLast();
    
    _updateFB('garage_door', {'status': status});
  }

  void toggleGarageLock(bool val) {
    _updateFB('garage_door', {'locked': val});
    if (val) toggleAutoOpenGarage(false);
    if (!val) {
      _evaluateGarageAutoOpen(reason: 'unlock');
    }
  }
  
  void toggleAutoOpenGarage(bool val) {
    if (garageLocked) return;
    _updateFB('garage_settings', {'autoOpen': val});
    if (val) {
      _evaluateGarageAutoOpen(reason: 'auto-open enabled');
    }
  }

  void toggleAutoCloseGarage(bool val) {
    _updateFB('garage_settings', {'autoClose': val});
    if (val && garageStatus == 'OPEN' && !garageCarPresent) {
      _startAutoCloseTimer();
    } else {
      _autoCloseCountdown?.cancel();
    }
  }
  
  void setAutoCloseTimer(double val) => _updateFB('garage_settings', {'autoCloseTimer': val});

  void simulateCarArrival() {
    _updateFB('garage_door', {'carPresent': true});
    _autoCloseCountdown?.cancel(); 
    _appendGarageLog('Car detected (simulation)');
    
    if (autoOpenGarage && garageBluetoothConnected && garageStatus == 'CLOSED') {
      setGarageDoor(true, source: 'simulation');
    }
  }

  void simulateCarDeparture() {
    _updateFB('garage_door', {'carPresent': false});
    if (autoCloseGarage && garageStatus == 'OPEN') {
      _startAutoCloseTimer();
    }
  }

  void _startAutoCloseTimer() {
    _autoCloseCountdown?.cancel();
    _autoCloseCountdown = Timer(Duration(seconds: autoCloseTimer.toInt()), () {
      if (garageStatus == 'OPEN' && !garageCarPresent) {
        setGarageStatus('CLOSED');
      }
    });
  }

  // --- GARDEN ACTIONS ---
  void toggleGardenPump(bool val) {
    _updateFB('garden_controls', {'gardenPumpRunning': val});
    if (val) toggleAutoGardenMode(false);
  }

  void toggleFirePump(bool val) {
    _updateFB('garden_controls', {'firePumpRunning': val});
    if (val) toggleAutoGardenMode(false);
  }

  void toggleAutoGardenMode(bool val) => _updateFB('garden_controls', {'autoGardenMode': val});
  void toggleAutoFire(bool val) => _updateFB('garden_controls', {'autoFireMode': val});
  void toggleSystemEnabled(bool val) => _updateFB('garden_controls', {'systemEnabled': val});

  void simulateSmokeAlert() {
    _updateFB('garden_sensors', {'smokeLevel': 'HIGH'});
    if (autoFireMode) {
      toggleFirePump(true);
      toggleAutoGardenMode(false);
    }
    String time = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
    fireAlertTime = time;
    gardenLog.insert(0, '🔥 Smoke detected: $time – Fire Pump activated');
    notifyListeners();
    
    Timer(const Duration(seconds: 10), () {
      _updateFB('garden_sensors', {'smokeLevel': 'NORMAL'});
      toggleFirePump(false);
      fireAlertTime = null;
      notifyListeners();
    });
  }
}
