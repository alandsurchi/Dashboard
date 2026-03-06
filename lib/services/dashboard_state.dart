import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'mqtt_service.dart';

class DeviceSchedule {
  final String deviceName;
  final TimeOfDay? onTime;
  final TimeOfDay? offTime;
  DeviceSchedule({required this.deviceName, this.onTime, this.offTime});
}

class DashboardState extends ChangeNotifier {
  final AuthService? auth;
  final FirestoreService? firestore;
  final MqttService? mqtt;
  
  StreamSubscription? _deviceSub;

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

  // --- GARAGE AUTOMATION ---
  String garageStatus = 'CLOSED'; 
  bool garageCarPresent = false;
  bool garageLocked = false;
  bool garageBluetoothConnected = false;
  
  bool autoOpenGarage = true;
  bool autoCloseGarage = false;
  double autoCloseTimer = 30; 
  List<String> garageLog = ['Garage closed at 13:58', 'Car exited at 13:56'];
  Timer? _autoCloseCountdown;

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

  DashboardState(this.auth, this.firestore, this.mqtt) {
    // Start the clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed) {
        currentTime = DateTime.now();
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

      // 2. Init Firestore
      if (firestore != null) {
        await firestore!.initializeDefaultDevices(uid);

        _deviceSub?.cancel();
        _deviceSub = firestore!.streamDevices(uid).listen((snapshot) {
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            _parseDeviceData(doc.id, data);
          }
          notifyListeners();
        });
      }
    }
  }

  void _handleMqttMessage(String topic, String payload) {
    try {
      if (topic.endsWith('/home_sensors/status')) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        
        bool changed = false;
        if (data.containsKey('temperature')) {
          temperature = (data['temperature'] as num).toDouble();
          changed = true;
        }
        if (data.containsKey('humidity')) {
          humidity = (data['humidity'] as num).toInt();
          changed = true;
        }
        if (data.containsKey('motionDetected')) {
          bool newMotion = data['motionDetected'] == true;
          if (newMotion != motionDetected) {
            motionDetected = newMotion;
            if (newMotion) {
              lastMotionTime = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
            }
            changed = true;
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

        if (data.containsKey('status')) {
          if (garageStatus != data['status']) {
            garageStatus = data['status'];
            changed = true;
          }
        }
        if (data.containsKey('carPresent')) {
          if (garageCarPresent != data['carPresent']) {
            garageCarPresent = data['carPresent'];
            changed = true;
          }
        }
        if (data.containsKey('bluetoothConnected')) {
          if (garageBluetoothConnected != data['bluetoothConnected']) {
            garageBluetoothConnected = data['bluetoothConnected'];
            changed = true;
          }
        }

        if (changed && !_isDisposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error parsing MQTT payload: $e");
    }
  }

  void _parseDeviceData(String id, Map<String, dynamic> data) {
    switch (id) {
      case 'led1': led1On = data['state'] ?? false; break;
      case 'led2': led2On = data['state'] ?? false; break;
      case 'led3': led3On = data['state'] ?? false; break;
      case 'fan': fanOn = data['state'] ?? false; break;
      case 'tv': tvOn = data['state'] ?? false; break;
      case 'wash': washOn = data['state'] ?? false; break;
      case 'rgb':
        rgbOn = data['state'] ?? false;
        rgbBrightness = (data['brightness'] ?? 1.0).toDouble();
        if (data.containsKey('r') && data.containsKey('g') && data.containsKey('b')) {
          rgbColor = Color.fromRGBO(data['r'], data['g'], data['b'], 1.0);
        }
        break;
      case 'home_sensors':
        temperature = (data['temperature'] ?? 24.5).toDouble();
        humidity = data['humidity'] ?? 55;
        motionDetected = data['motionDetected'] ?? false;
        break;
      case 'door':
        doorStatus = data['status'] ?? 'CLOSED';
        break;
      case 'garage_door':
        garageStatus = data['status'] ?? 'CLOSED';
        garageCarPresent = data['carPresent'] ?? false;
        garageBluetoothConnected = data['bluetoothConnected'] ?? false;
        garageLocked = data['locked'] ?? false;
        break;
      case 'garage_settings':
        autoOpenGarage = data['autoOpen'] ?? true;
        autoCloseGarage = data['autoClose'] ?? false;
        autoCloseTimer = (data['autoCloseTimer'] ?? 30.0).toDouble();
        break;
      case 'garden_sensors':
        soilMoisture = (data['soilMoisture'] ?? 45.0).toDouble();
        smokeLevel = data['smokeLevel'] ?? 'NORMAL';
        gardenTemp = (data['gardenTemp'] ?? 28.0).toDouble();
        gardenHumidity = data['gardenHumidity'] ?? 40;
        tankLevel = (data['tankLevel'] ?? 75.0).toDouble();
        break;
      case 'garden_controls':
        gardenPumpRunning = data['gardenPumpRunning'] ?? false;
        firePumpRunning = data['firePumpRunning'] ?? false;
        autoGardenMode = data['autoGardenMode'] ?? true;
        autoFireMode = data['autoFireMode'] ?? true;
        systemEnabled = data['systemEnabled'] ?? true;
        break;
    }
  }

  Future<void> _updateFB(String docId, Map<String, dynamic> data) async {
    final uid = auth?.currentUser?.uid;
    if (uid != null) {
      // Optimistically update local UI immediately
      _parseDeviceData(docId, data);
      if (!_isDisposed) notifyListeners();
      
      // Update Database
      if (firestore != null) {
        await firestore!.updateDeviceState(uid, docId, data);
      }
      
      // Send Real-time MQTT Command to ESP32
      if (mqtt != null && mqtt!.isConnected) {
        mqtt!.publishCommand(uid, docId, data);
      }
    }
  }


  @override
  void dispose() {
    _isDisposed = true;
    _clockTimer.cancel();
    _autoCloseCountdown?.cancel();
    _deviceSub?.cancel();
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

  void setGarageDoor(bool open) {
    String newStatus = open ? 'OPEN' : 'CLOSED';
    if (garageStatus != newStatus) {
      _updateFB('garage_door', {'status': newStatus, 'state': open});

      // Send BOTH keys so the ESP32 can parse either format
      if (mqtt != null && mqtt!.isConnected) {
        final uid = auth?.currentUser?.uid;
        if (uid != null) {
          mqtt!.publishCommand(uid, 'garage_door', {'state': open, 'status': newStatus});
        }
      }
      _updateLogs('garageLog', open ? 'Garage opened remotely' : 'Garage closed');
    }
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
  }
  
  void toggleAutoOpenGarage(bool val) {
    if (garageLocked) return;
    _updateFB('garage_settings', {'autoOpen': val});
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
    
    String time = "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}";
    garageLog.insert(0, 'Car detected at $time');
    
    if (autoOpenGarage && garageBluetoothConnected && garageStatus == 'CLOSED') {
      setGarageStatus('OPEN');
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
