// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:math';

import 'package:ble_demo/ble_controller.dart';
import 'package:ble_demo/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:get/get.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:  FlutterBlueApp(),
    );
  }
}


class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme.displayMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 10)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 10))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.id.toString()),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: d.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (c, snapshot) {
                        if (snapshot.data ==
                            BluetoothDeviceState.connected) {
                          return ElevatedButton(
                            child: Text('OPEN'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        DeviceScreen(device: d))),
                          );
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map(
                        (r) => ScanResultTile(
                      result: r,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        r.device.connect();
                        return DeviceScreen(device: r.device);
                      })),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 20)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {

   DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  TextEditingController textController = TextEditingController();

  BluetoothCharacteristic? selectedCharacteristic;

  List<int> getRandomBytes(String value) {

    // var value = "GNID";//SNID 0000BF260468\r\n
    // var value = "GNID";
    List<int> bytesToWrite = utf8.encode(value);
    return bytesToWrite;

    //
    // final math = Random();
    // return [
    //   math.nextInt(255),
    //   math.nextInt(255),
    //   math.nextInt(255),
    //   math.nextInt(255)
    // ];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
        service: s,
        characteristicTiles: s.characteristics
            .map(
              (c) => CharacteristicTile(
            characteristic: c,
            onReadPressed: () => c.read(),

            onWritePressed: () async {
              selectedCharacteristic = c;


              await c.write(getRandomBytes("SNID 0000BF260468\r\n"),withoutResponse: false).then((value) {

                print("WRITE VALUE");
                // print(String.fromCharCodes(value));
                print(value);
              });
              await c.read().then((value) {
                print("READ VALUE");
                print(String.fromCharCodes(value));

              });

            },
            onNotificationPressed: () async {
              await c.setNotifyValue(!c.isNotifying);
              await c.read();
            },
            descriptorTiles: c.descriptors
                .map(
                  (d) => DescriptorTile(
                descriptor: d,
                onReadPressed: () => d.read(),
                onWritePressed: () => d.write(getRandomBytes("")),
              ),
            )
                .toList(),
          ),
        )
            .toList(),
      ),
    )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: widget.device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => widget.device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => widget.device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: widget.device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${widget.device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: widget.device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => widget.device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: widget.device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => widget.device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Wrap(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue
                      ),
                      child: TextField(
                        controller: textController,
                      ),
                    ),
                    ElevatedButton(
                        onPressed: () async {

                          await selectedCharacteristic?.write(getRandomBytes(textController.text),withoutResponse: false).then((value) {

                            print("WRITE VALUE");
                            // print(String.fromCharCodes(value));
                            print(value);
                          });
                          await selectedCharacteristic?.read().then((value) {
                            print("READ VALUE");
                            print(String.fromCharCodes(value));

                          });
                        },
                        child: Text("send")),
                    Column(
                      children: _buildServiceTiles(snapshot.data!),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
//
// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key});
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   FlutterBlue flutterBlue = FlutterBlue.instance;
//   BluetoothDevice? selectedDevice;
//   BluetoothCharacteristic? selectedCharacteristic;
//   List<BluetoothDevice> devices = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initBluetooth();
//   }
//
//   void _initBluetooth() {
//     flutterBlue.state.listen((state) {
//       if (state == BluetoothState.on) {
//         _startScanning();
//       }
//     });
//   }
//
//   void _startScanning() {
//     flutterBlue.scanResults.listen((results) {
//       for (ScanResult result in results) {
//         if (!devices.contains(result.device)) {
//           setState(() {
//             devices.add(result.device);
//           });
//         }
//       }
//     });
//
//     flutterBlue.startScan();
//   }
//
//   void _connectToDevice(BluetoothDevice device) async {
//     flutterBlue.stopScan();
//     await device.connect();
//     List<BluetoothService> services = await device.discoverServices();
//
//     // Replace the UUID with the characteristic you want to read/write
//     for (BluetoothService service in services) {
//       print(service.uuid.toString());
//       for (BluetoothCharacteristic characteristic in service.characteristics) {
//         if (characteristic.uuid.toString() == device.id.id) {
//           setState(() {
//             selectedDevice = device;
//             selectedCharacteristic = characteristic;
//           });
//           print("Selected Device - ${selectedDevice?.name!.toString()}");
//         }
//       }
//     }
//   }
//
//   void _readCharacteristic() async {
//     if(selectedCharacteristic != null){
//
//       List<int> value = await selectedCharacteristic!.read();
//       print("Read value: $value");
//     }else{
//       print("selectedCharacteristic not found");
//     }
//   }
//
//   void _writeCharacteristic() async {
//     List<int> valueToWrite = [1, 2, 3]; // Replace with your data
//
//     if(selectedCharacteristic != null){
//
//       await selectedCharacteristic!.write(valueToWrite);
//       print("Write successful");
//
//     }else{
//       print("selectedCharacteristic not found for writing");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Bluetooth App'),
//       ),
//       body: Column(
//         children: [
//           Text('Available Devices:'),
//           Expanded(
//             child: ListView.builder(
//               itemCount: devices.length,
//               itemBuilder: (context, index) {
//                 BluetoothDevice device = devices[index];
//                 return ListTile(
//                   title: Text(device.name ?? 'Unknown Device'),
//                   subtitle: Text(device.id.toString()),
//                   onTap: () {
//                     _connectToDevice(device);
//                   },
//                 );
//               },
//             ),
//           ),
//           if (selectedDevice != null)
//             Column(
//               children: [
//                 Text('Connected to: ${selectedDevice!.name}'),
//                 ElevatedButton(
//                   onPressed: _readCharacteristic,
//                   child: Text('Read Characteristic'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _writeCharacteristic,
//                   child: Text('Write Characteristic'),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }