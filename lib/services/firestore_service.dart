import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream all devices for a specific user
  Stream<QuerySnapshot> streamDevices(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .snapshots();
  }

  // Stream a single device for a specific user
  Stream<DocumentSnapshot> streamDevice(String uid, String deviceId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .snapshots();
  }

  // Update specific fields of a device
  Future<void> updateDeviceState(String uid, String deviceId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set(data, SetOptions(merge: true)); // Use set with merge to create if not exists
  }

  // Seed default devices if the devices collection is empty
  Future<void> initializeDefaultDevices(String uid) async {
    final devicesRef = _db.collection('users').doc(uid).collection('devices');
    final snapshot = await devicesRef.limit(1).get();

    if (snapshot.docs.isEmpty) {
      // Setup Home Control Devices
      final batch = _db.batch();

      batch.set(devicesRef.doc('led1'), {'type': 'light', 'name': 'Living Room Light 1', 'state': false});
      batch.set(devicesRef.doc('led2'), {'type': 'light', 'name': 'Living Room Light 2', 'state': false});
      batch.set(devicesRef.doc('led3'), {'type': 'light', 'name': 'Kitchen Light', 'state': false});
      batch.set(devicesRef.doc('fan'), {'type': 'appliance', 'name': 'Cooling Fan', 'state': false});
      batch.set(devicesRef.doc('tv'), {'type': 'appliance', 'name': 'Living Room TV', 'state': false});
      batch.set(devicesRef.doc('wash'), {'type': 'appliance', 'name': 'Washing Machine', 'state': false});
      batch.set(devicesRef.doc('rgb'), {'type': 'rgb', 'name': 'Ambient RGB', 'state': false, 'color': '#2196F3', 'brightness': 1.0});
      batch.set(devicesRef.doc('home_sensors'), {'type': 'sensor', 'temperature': 24.5, 'humidity': 55, 'motionDetected': false, 'lastMotionTime': '14:25'});
      batch.set(devicesRef.doc('door'), {'type': 'door', 'name': 'Front Door', 'status': 'CLOSED'});
      
      // Setup Garage Devices
      batch.set(devicesRef.doc('garage_door'), {'type': 'garage', 'name': 'Garage Door', 'status': 'CLOSED', 'carPresent': false, 'locked': false});
      batch.set(devicesRef.doc('garage_settings'), {'type': 'settings', 'autoOpen': true, 'autoClose': false, 'autoCloseTimer': 30.0});

      // Setup Garden Devices
      batch.set(devicesRef.doc('garden_sensors'), {'type': 'sensor', 'soilMoisture': 45.0, 'smokeLevel': 'NORMAL', 'gardenTemp': 28.0, 'gardenHumidity': 40, 'tankLevel': 75.0});
      batch.set(devicesRef.doc('garden_controls'), {'type': 'pump', 'gardenPumpRunning': false, 'firePumpRunning': false, 'autoGardenMode': true, 'autoFireMode': true, 'systemEnabled': true});

      await batch.commit();
      print('Initialized default devices for user: $uid');
    }
  }
}
