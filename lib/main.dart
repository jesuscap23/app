import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io'; // For detecting the operating system
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter BLE Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterReactiveBle _flutterReactiveBle = FlutterReactiveBle();
  final Uuid serviceUuid = Uuid.parse("180F");
  final Uuid accelCharacteristicUuid = Uuid.parse("2A19"); // Accelerometer Characteristic UUID
  final Uuid gyroCharacteristicUuid = Uuid.parse("2A1A"); // Gyroscope Characteristic UUID
  final Uuid magCharacteristicUuid = Uuid.parse("2A1B"); // Magnetometer Characteristic UUID

  String _log = "";
  DiscoveredDevice? _connectedDevice;
  QualifiedCharacteristic? _accelCharacteristic;
  QualifiedCharacteristic? _gyroCharacteristic;
  QualifiedCharacteristic? _magCharacteristic;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<List<int>>? _accelDataSubscription;
  StreamSubscription<List<int>>? _gyroDataSubscription;
  StreamSubscription<List<int>>? _magDataSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    if (Platform.isAndroid) {
      int androidVersion = int.parse(Platform.operatingSystemVersion.split(' ')[1]);
      if (androidVersion >= 12) {
        if (!await Permission.bluetoothScan.isGranted) {
          _log += 'Bluetooth Scan permission missing. Please grant it.\n';
        }
        if (!await Permission.bluetoothConnect.isGranted) {
          _log += 'Bluetooth Connect permission missing. Please grant it.\n';
        }
      } else {
        if (!await Permission.locationWhenInUse.isGranted) {
          _log += 'Location permission missing. Please grant it.\n';
        }
      }
      setState(() {});
    }
  }

  Future<void> _requestPermissions() async {
    _log += 'Requesting permissions...\n';
    setState(() {});

    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final androidVersion = androidInfo.version.sdkInt;

      if (androidVersion >= 12) {
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
        if (bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted) {
          _log += 'Bluetooth permissions granted.\n';
          _connectToArduino();
        } else {
          _log += 'Bluetooth permissions denied.\n';
        }
      } else {
        final locationStatus = await Permission.locationWhenInUse.request();
        if (locationStatus.isGranted) {
          _log += 'Location permission granted.\n';
          _connectToArduino();
        } else {
          _log += 'Location permission denied.\n';
        }
      }
    } else {
      _log += 'Not android.\n';
    }
    setState(() {});
  }

  void _connectToArduino() async {
    _log += 'Scanning for devices...\n';
    setState(() {});

    _scanSubscription = _flutterReactiveBle
        .scanForDevices(
      withServices: [serviceUuid],
      scanMode: ScanMode.lowLatency,
    )
        .timeout(const Duration(seconds: 10))
        .listen(
          (device) {
        if (device.name == "Nano33_IMU") {
          _log += 'Device found: ${device.name}\n';
          setState(() {});

          _connectedDevice = device;
          _scanSubscription?.cancel(); // Stop scanning after finding the device

          _connectionSubscription = _flutterReactiveBle.connectToDevice(id: device.id).listen(
                (state) {
              if (state.connectionState == DeviceConnectionState.connected) {
                _log += 'Connected to the device.\n';

                // Set up the characteristics for reading data
                _accelCharacteristic = QualifiedCharacteristic(
                  serviceId: serviceUuid,
                  characteristicId: accelCharacteristicUuid,
                  deviceId: device.id,
                );

                _gyroCharacteristic = QualifiedCharacteristic(
                  serviceId: serviceUuid,
                  characteristicId: gyroCharacteristicUuid,
                  deviceId: device.id,
                );

                _magCharacteristic = QualifiedCharacteristic(
                  serviceId: serviceUuid,
                  characteristicId: magCharacteristicUuid,
                  deviceId: device.id,
                );

                _subscribeToData();
              } else if (state.connectionState == DeviceConnectionState.disconnected) {
                _log += 'Disconnected from the device.\n';
                _connectedDevice = null;
                _connectionSubscription?.cancel();
                _accelDataSubscription?.cancel();
                _gyroDataSubscription?.cancel();
                _magDataSubscription?.cancel();
              }
              setState(() {});
            },
            onError: (error) {
              _log += 'Connection error: $error\n';
              setState(() {});
            },
          );
        }
      },
      onError: (error) {
        _log += 'Scan error: $error\n';
        setState(() {});
      },
    );
  }

  void _subscribeToData() {
    if (_accelCharacteristic != null) {
      _accelDataSubscription = _flutterReactiveBle
          .subscribeToCharacteristic(_accelCharacteristic!)
          .listen(
            (data) {
          final receivedAccel = String.fromCharCodes(data);
          _log += 'Accelerometer data: $receivedAccel\n';
          setState(() {});
        },
        onError: (error) {
          _log += 'Error receiving accelerometer data: $error\n';
          setState(() {});
        },
      );
    }

    if (_gyroCharacteristic != null) {
      _gyroDataSubscription = _flutterReactiveBle
          .subscribeToCharacteristic(_gyroCharacteristic!)
          .listen(
            (data) {
          final receivedGyro = String.fromCharCodes(data);
          _log += 'Gyroscope data: $receivedGyro\n';
          setState(() {});
        },
        onError: (error) {
          _log += 'Error receiving gyroscope data: $error\n';
          setState(() {});
        },
      );
    }

    if (_magCharacteristic != null) {
      _magDataSubscription = _flutterReactiveBle
          .subscribeToCharacteristic(_magCharacteristic!)
          .listen(
            (data) {
          final receivedMag = String.fromCharCodes(data);
          _log += 'Magnetometer data: $receivedMag\n';
          setState(() {});
        },
        onError: (error) {
          _log += 'Error receiving magnetometer data: $error\n';
          setState(() {});
        },
      );
    }
  }

  void _disconnectFromArduino() {
    if (_connectionSubscription != null) {
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      _connectedDevice = null;
      _log += 'Disconnected from the device manually.\n';
      setState(() {});
    } else {
      _log += 'No active connection to disconnect.\n';
      setState(() {});
    }

    // Cancel scanning if it's still active
    _scanSubscription?.cancel();
    _scanSubscription = null;

    // Cancel data subscriptions
    _accelDataSubscription?.cancel();
    _gyroDataSubscription?.cancel();
    _magDataSubscription?.cancel();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _accelDataSubscription?.cancel();
    _gyroDataSubscription?.cancel();
    _magDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('Connect to Arduino'),
            ),
            ElevatedButton(
              onPressed: _disconnectFromArduino,
              child: const Text('Disconnect from Arduino'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_log),
              ),
            ),
          ],
        ),
      ),
    );
  }
}