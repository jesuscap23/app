import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  int _counter = 0;
  final _flutterReactiveBle = FlutterReactiveBle();
  final serviceUuid = Uuid.parse("180F");
  String _log = "";

  Future<void> _requestLocationPermission() async {
    // Add rationale for location permission
    _log += 'Requesting location permission...\n';
    setState(() {});
    // You can show a dialog or snackbar here explaining why location permission is needed

    final status = await Permission.location.request();

    if (status.isGranted) {
      _connectToArduino();
    } else {
      _log += 'Location permission denied.\n';
      setState(() {});
    }
  }

  void _incrementCounter() {
    setState(() {
      _log += 'plus 1\n';
      _counter++;
    });
  }

  void _connectToArduino() async {
    try {
      if (await Permission.location.isGranted) {
        _log += 'Connecting... to the device\n';
        setState(() {});

        // Add timeout to scanning
        _flutterReactiveBle.scanForDevices(
          withServices: [serviceUuid],
          scanMode: ScanMode.lowLatency,
          timeout: const Duration(seconds: 10), // Example timeout
        ).listen(
              (device) {
            if (device.name == "Nano33_IMU") {
              _flutterReactiveBle
                  .connectToDevice(id: device.id)
                  .listen((state) {
                if (state.connectionState ==
                    DeviceConnectionState.connected) {
                  _log += 'Connected to the device\n';
                  setState(() {});
                  // You can start data exchange here
                } else if (state.connectionState ==
                    DeviceConnectionState.disconnected) {
                  _log += 'Disconnected from the device\n';
                  setState(() {});
                }
              }, onError: (Object e) {
                _log += 'Cannot connect, exception occured: ${e.toString()}\n';
                setState(() {});
              });
            }
          },
          onError: (Object e) {
            _log += 'Cannot connect, exception occured: ${e.toString()}\n';
            setState(() {});
          },
        );
      } else {
        _requestLocationPermission();
      }
    } catch (e) {
      // Add more specific error handling
      // if (e is SomeSpecificException) {
      //   // Handle specific exception
      // } else {
      _log += 'Cannot connect, exception occured: ${e.toString()}\n';
      // }
      setState(() {});
    }
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
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              child: const Text('Connect to Arduino'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_log),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}