import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dart_ssh2/dart_ssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const UbntControllerApp());
}

class UbntControllerApp extends StatelessWidget {
  const UbntControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UBNT Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const DashboardScreen(),
    );
  }
}

class SectorModel {
  String id;
  String name;
  String ip;
  String user;
  String pass;
  bool isConnected;
  int clientCount;
  bool isLoading;

  SectorModel({
    required this.id,
    required this.name,
    required this.ip,
    required this.user,
    required this.pass,
    this.isConnected = false,
    this.clientCount = 0,
    this.isLoading = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'user': user,
        'pass': pass,
      };

  factory SectorModel.fromJson(Map<String, dynamic> json) => SectorModel(
        id: json['id'],
        name: json['name'],
        ip: json['ip'],
        user: json['user'],
        pass: json['pass'],
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SectorModel> sectors = [];
  bool autoKickEnabled = false;
  int intervalMinutes = 5;
  Timer? autoKickTimer;
  bool isGlobalLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('saved_sectors');

    if (data != null && data.isNotEmpty) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        sectors = jsonList.map((e) => SectorModel.fromJson(e)).toList();
      });
    } else {
      sectors = [
        SectorModel(id: '1', name: "Sector 1", ip: "10.181.131.18", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '2', name: "Sector 2", ip: "10.181.131.12", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '3', name: "Sector 3", ip: "10.181.131.19", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '4', name: "Sector 4", ip: "10.181.131.7", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '5', name: "Sector 5", ip: "10.181.131.16", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '6', name: "Sector 6", ip: "10.181.131.11", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '7', name: "Sector 7", ip: "10.181.131.15", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '8', name: "Sector 8", ip: "10.181.131.13", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '9', name: "Sector 9", ip: "10.181.131.28", user: "ubnt", pass: "ubnt0."),
        SectorModel(id: '10', name: "Sector 10", ip: "10.181.131.26", user: "ubnt", pass: "ubnt0."),
      ];
      _saveSectors();
    }
  }

  Future<void> _saveSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(sectors.map((e) => e.toJson()).toList());
    await prefs.setString('saved_sectors', data);
  }

  Future<void> kickSector(SectorModel sector) async {
    setState(() => sector.isLoading = true);
    try {
      final socket = await SSHSocket.connect(sector.ip, 22, timeout: const Duration(seconds: 4));
      final client = SSHClient(
        socket,
        username: sector.user,
        onPasswordRequest: () => sector.pass,
      );

      final result = await client.run('wstalist');
      final output = utf8.decode(result);

      int count = 0;
      if (output.trim().isNotEmpty) {
        final List<dynamic> stations = jsonDecode(output);
        for (var sta in stations) {
          final mac = sta['mac'];
          if (mac != null) {
            await client.run('iwpriv ath0 kickmac $mac');
            count++;
          }
        }
      }

      client.close();
      setState(() {
        sector.isConnected = true;
        sector.clientCount = count;
      });
    } catch (_) {
      setState(() {
        sector.isConnected = false;
        sector.clientCount = 0;
      });
    } finally {
      setState(() => sector.isLoading = false);
    }
  }

  Future<void> kickAllSectors() async {
    setState(() => isGlobalLoading = true);
    await Future.wait(sectors.map((s) => kickSector(s)));
    setState(() => isGlobalLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تنفيذ عملية الطرد لجميع السكاتر'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void toggleAutoKick(bool? value) {
    setState(() {
      autoKickEnabled = value ?? false;
      if (autoKickEnabled) {
        autoKickTimer = Timer.periodic(
          Duration(minutes: intervalMinutes),
          (_) => kickAllSectors(),
        );
      } else {
        autoKickTimer?.cancel();
      }
    });
  }

  void _openSectorDialog([SectorModel? sector]) {
    final nameController = TextEditingController(text: sector?.name ?? '');
    final ipController = TextEditingController(text: sector?.ip ?? '');
    final userController = TextEditingController(text: sector?.user ?? 'ubnt');
    final passController = TextEditingController(text: sector?.pass ?? 'ubnt0.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sector == null ? 'إضافة سكتر جديد' : 'تعديل بيانات السكتر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم السكتر')),
              TextField(controller: ipController, decoration: const InputDecoration(labelText: 'عنوان IP')),
              TextField(controller: userController, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              TextField(controller: passController, decoration: const InputDecoration(labelText: 'كلمة السر'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ipController.text.isEmpty || nameController.text.isEmpty) return;

              setState(() {
                if (sector == null) {
                  sectors.add(SectorModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    ip: ipController.text,
                    user: userController.text,
                    pass: passController.text,
                  ));
                } else {
                  sector.name = nameController.text;
                  sector.ip = ipController.text;
                  sector.user = userController.text;
                  sector.pass = passController.text;
                }
              });

              _saveSectors();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteSector(SectorModel sector) {
    setState(() {
      sectors.removeWhere((s) => s.id == sector.id);
    });
    _saveSectors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UBNT Multi-Sector Manager'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة سكتر',
            onPressed: () => _openSectorDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: autoKickEnabled,
                        onChanged: toggleAutoKick,
                        activeColor: Colors.blueAccent,
                      ),
                      Text(
                        autoKickEnabled ? 'الفصل التلقائي مفعل' : 'الفصل التلقائي معطل',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: intervalMinutes,
                    dropdownColor: const Color(0xFF1E1E1E),
                    items: [1, 3, 5, 10, 15]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m دقائق')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => intervalMinutes = val);
                        if (autoKickEnabled) toggleAutoKick(true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: sectors.isEmpty
                ? const Center(child: Text('لا يوجد سكاتر مضافة.'))
                : ListView.builder(
                    itemCount: sectors.length,
                    itemBuilder: (context, index) {
                      final sector = sectors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: sector.isConnected
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            child: Icon(
                              sector.isConnected ? Icons.wifi : Icons.wifi_off,
                              color: sector.isConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(sector.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${sector.ip} • متصل: ${sector.clientCount}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                onPressed: () => _openSectorDialog(sector),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                onPressed: () => _deleteSector(sector),
                              ),
                              sector.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.flash_on, color: Colors.amber),
                                      onPressed: () => kickSector(sector),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isGlobalLoading ? null : kickAllSectors,
              icon: isGlobalLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new, color: Colors.white),
              label: Text(
                isGlobalLoading ? 'جاري الفصل...' : 'طرد المشتركين من جميع السكاتر',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
