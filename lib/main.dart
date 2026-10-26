import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const CoolerApp());
}

// ==========================================
// سرویس مدیریت بلوتوث کلاسیک (HC-05, HC-06, ...)
// ==========================================
class BluetoothServiceClass {
  BluetoothConnection? _connection;
  bool get isConnected => _connection?.isConnected ?? false;
  
  StringBuffer _buffer = StringBuffer();

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print("Error getting bonded devices: $e");
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _buffer.clear();
      return true;
    } catch (e) {
      print("Connection error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _buffer.clear();
  }

  Future<void> sendCommand(String command) async {
    if (isConnected && _connection != null) {
      String cmdWithNewline = command.endsWith('\n') ? command : '$command\n';
      _connection!.output.add(Uint8List.fromList(utf8.encode(cmdWithNewline)));
      await _connection!.output.allSent;
      print(">> Sent: $cmdWithNewline");
    } else {
      print("Not connected!");
    }
  }

  void listenToData(Function(String) onDataReceived) {
    _connection?.input?.listen((Uint8List data) {
      String incoming = utf8.decode(data);
      _buffer.write(incoming);
      
      if (incoming.contains('\n')) {
        String allData = _buffer.toString();
        List<String> lines = allData.split('\n');
        
        _buffer.clear();
        _buffer.write(lines.removeLast());
        
        for (String line in lines) {
          if (line.trim().isNotEmpty) {
            onDataReceived(line.trim());
          }
        }
      }
    }).onDone(() {
      print("Connection closed by remote device");
    });
  }
}

// ==========================================
// بدنه اصلی برنامه
// ==========================================
class CoolerApp extends StatelessWidget {
  const CoolerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooler Control',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainContainer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  final BluetoothServiceClass _bluetoothService = BluetoothServiceClass();
  final List<String> _logs = [];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(bluetoothService: _bluetoothService),
      TimerScreen(bluetoothService: _bluetoothService),
      StatusScreen(bluetoothService: _bluetoothService, logs: _logs),
      SettingsScreen(bluetoothService: _bluetoothService, logs: _logs),
    ];

    _bluetoothService.listenToData((line) {
      setState(() {
        _logs.add(line);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooler Control'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'تایمر'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'وضعیت'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

// ==========================================
// صفحه ۱: Home (با آیکون‌های زیبا و بدون نمایش دستور)
// ==========================================
class HomeScreen extends StatelessWidget {
  final BluetoothServiceClass bluetoothService;
  const HomeScreen({Key? key, required this.bluetoothService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.thermostat, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text("Temp: -- °C | Hum: -- %", style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildControlCard("پمپ", Icons.water_drop, "1", Colors.blue),
                _buildControlCard("دور کند", Icons.slow_motion_video, "2", Colors.amber),
                _buildControlCard("دور تند", Icons.fast_forward, "3", Colors.deepOrange),
                _buildControlCard("حالت", Icons.sync, "4", Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(String title, IconData icon, String cmd, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => bluetoothService.sendCommand(cmd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// صفحه ۲: Timer
// ==========================================
class TimerScreen extends StatefulWidget {
  final BluetoothServiceClass bluetoothService;
  const TimerScreen({Key? key, required this.bluetoothService}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int onHour = 7, onMinute = 30;
  int offHour = 19, offMinute = 30;

  void _sendTimerSettings() async {
    String onStr = "ON${onHour.toString().padLeft(2, '0')}${onMinute.toString().padLeft(2, '0')}";
    String offStr = "OFF${offHour.toString().padLeft(2, '0')}${offMinute.toString().padLeft(2, '0')}";

    await widget.bluetoothService.sendCommand(onStr);
    await Future.delayed(const Duration(milliseconds: 500));
    await widget.bluetoothService.sendCommand(offStr);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تنظیمات تایمر ارسال شد")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text("ساعت روشن شدن (ON)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildTimePickers((h, m) => setState(() { onHour = h; onMinute = m; }), onHour, onMinute),
          const Divider(height: 30),
          const Text("ساعت خاموش شدن (OFF)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildTimePickers((h, m) => setState(() { offHour = h; offMinute = m; }), offHour, offMinute),
          const SizedBox(height: 20),
          Text(
            "پیش‌نمایش: ON: ${onHour.toString().padLeft(2, '0')}:${onMinute.toString().padLeft(2, '0')} | OFF: ${offHour.toString().padLeft(2, '0')}:${offMinute.toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: _sendTimerSettings,
            child: const Text("ذخیره و ارسال تایمر", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickers(Function(int, int) onChanged, int currentH, int currentM) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: currentH,
          items: List.generate(24, (index) => DropdownMenuItem(value: index, child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)))),
          onChanged: (val) => onChanged(val!, currentM),
        ),
        const Text(" : ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        DropdownButton<int>(
          value: currentM,
          items: List.generate(60, (index) => DropdownMenuItem(value: index, child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)))),
          onChanged: (val) => onChanged(currentH, val!),
        ),
      ],
    );
  }
}

// ==========================================
// صفحه ۳: Status
// ==========================================
class StatusScreen extends StatelessWidget {
  final BluetoothServiceClass bluetoothService;
  final List<String> logs;
  const StatusScreen({Key? key, required this.bluetoothService, required this.logs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
            onPressed: () => bluetoothService.sendCommand("s"),
            icon: const Icon(Icons.refresh),
            label: const Text("به‌روزرسانی وضعیت"),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// صفحه ۴: Settings
// ==========================================
class SettingsScreen extends StatefulWidget {
  final BluetoothServiceClass bluetoothService;
  final List<String> logs;
  const SettingsScreen({Key? key, required this.bluetoothService, required this.logs}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  String rtcInput = "";
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });
    List<BluetoothDevice> devices = await widget.bluetoothService.getPairedDevices();
    setState(() {
      _devices = devices;
      _isLoadingDevices = false;
    });
  }

  void _pressKey(String digit) {
    if (rtcInput.length < 4) {
      setState(() {
        rtcInput += digit;
      });
    }
  }

  void _sendRtc() {
    if (rtcInput.length == 4) {
      widget.bluetoothService.sendCommand("S$rtcInput");
      setState(() {
        rtcInput = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ساعت RTC تنظیم شد")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لطفاً ۴ رقم وارد کنید")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayTime = "";
    if (rtcInput.isEmpty) {
      displayTime = "-- : --";
    } else if (rtcInput.length == 1) {
      displayTime = "0${rtcInput} : --";
    } else if (rtcInput.length == 2) {
      displayTime = "${rtcInput} : --";
    } else if (rtcInput.length == 3) {
      displayTime = "${rtcInput.substring(0, 2)} : 0${rtcInput.substring(2)}";
    } else {
      displayTime = "${rtcInput.substring(0, 2)} : ${rtcInput.substring(2)}";
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text("اتصال به ماژول بلوتوث", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: DropdownButton<BluetoothDevice>(
                  isExpanded: true,
                  hint: const Text("انتخاب دستگاه جفت‌شده"),
                  value: _selectedDevice,
                  items: _devices.map((device) {
                    return DropdownMenuItem(
                      value: device,
                      child: Text("${device.name ?? 'Unknown'} (${device.address})"),
                    );
                  }).toList(),
                  onChanged: (device) => setState(() => _selectedDevice = device),
                ),
              ),
              IconButton(
                icon: _isLoadingDevices 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.refresh, color: Colors.blue),
                onPressed: _loadDevices,
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedDevice != null ? () async {
                    bool res = await widget.bluetoothService.connect(_selectedDevice!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res ? "متصل شد!" : "خطا در اتصال")),
                    );
                    setState(() {});
                  } : null,
                  child: const Text("اتصال"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    await widget.bluetoothService.disconnect();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("قطع شد")));
                  },
                  child: const Text("قطع اتصال"),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          const Text("تنظیم ساعت RTC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              displayTime,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              ...List.generate(9, (index) => ElevatedButton(onPressed: () => _pressKey((index + 1).toString()), child: Text('${index + 1}', style: const TextStyle(fontSize: 18)))),
              ElevatedButton(onPressed: () => setState(() => rtcInput = ""), child: const Text('C', style: TextStyle(fontSize: 16, color: Colors.red))),
              ElevatedButton(onPressed: () => _pressKey('0'), child: const Text('0', style: const TextStyle(fontSize: 18))),
              ElevatedButton(onPressed: () { if (rtcInput.isNotEmpty) setState(() => rtcInput = rtcInput.substring(0, rtcInput.length - 1)); }, child: const Text('⌫', style: const TextStyle(fontSize: 18))),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(45)),
            onPressed: _sendRtc,
            child: const Text("ارسال تنظیم ساعت RTC", style: TextStyle(fontSize: 16)),
          ),
          const Divider(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                widget.logs.clear();
              });
            },
            icon: const Icon(Icons.delete),
            label: const Text("پاک کردن لاگ‌ها"),
          )
        ],
      ),
    );
  }
}
