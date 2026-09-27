import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MaterialApp(
    home: UbntApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class SectorModel {
  String ip;
  String username;
  String password;

  SectorModel({
    required this.ip,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'username': username,
        'password': password,
      };

  factory SectorModel.fromJson(Map<String, dynamic> json) => SectorModel(
        ip: json['ip'] ?? '',
        username: json['username'] ?? 'ubnt',
        password: json['password'] ?? 'ubnt0.',
      );
}

class UbntApp extends StatefulWidget {
  const UbntApp({super.key});

  @override
  State<UbntApp> createState() => _UbntAppState();
}

class _UbntAppState extends State<UbntApp> {
  List<SectorModel> sectors = [];
  String statusLog = 'جاهز للبدء...';

  @override
  void initState() {
    super.initState();
    _loadSectors();
  }

  // تحميل البيانات المحفوظة
  Future<void> _loadSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('sectors_data');

    if (savedData != null) {
      final List<dynamic> jsonList = jsonDecode(savedData);
      setState(() {
        sectors = jsonList.map((item) => SectorModel.fromJson(item)).toList();
      });
    } else {
      // القائمة الافتراضية لأول مرة
      setState(() {
        sectors = List.generate(
          10,
          (index) => SectorModel(
            ip: '10.181.131.${index + 1}',
            username: 'ubnt',
            password: 'ubnt0.',
          ),
        );
      });
      _saveSectors();
    }
  }

  // حفظ البيانات في الموبايل
  Future<void> _saveSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(sectors.map((s) => s.toJson()).toList());
    await prefs.setString('sectors_data', encodedData);
  }

  // نافذة تعديل أو إضافة سكتر
  void _showSectorDialog({int? index}) {
    final isEditing = index != null;
    TextEditingController ipController = TextEditingController(
      text: isEditing ? sectors[index].ip : '10.181.131.',
    );
    TextEditingController userController = TextEditingController(
      text: isEditing ? sectors[index].username : 'ubnt',
    );
    TextEditingController passController = TextEditingController(
      text: isEditing ? sectors[index].password : 'ubnt0.',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل بيانات السكتر' : 'إضافة سكتر جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'IP السكتر',
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم (Username)',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة السر (Password)',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  sectors.removeAt(index);
                });
                _saveSectors();
                Navigator.pop(context);
              },
              child: const Text('حذف السكتر', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (isEditing) {
                  sectors[index].ip = ipController.text;
                  sectors[index].username = userController.text;
                  sectors[index].password = passController.text;
                } else {
                  sectors.add(SectorModel(
                    ip: ipController.text,
                    username: userController.text,
                    password: passController.text,
                  ));
                }
              });
              _saveSectors();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // فصل المشتركين عن طريق SSH
  Future<void> disconnectClients(SectorModel sector) async {
    setState(() {
      statusLog = 'جاري الاتصال بـ ${sector.ip}...';
    });

    try {
      final socket = await SSHSocket.connect(
        sector.ip,
        22,
        timeout: const Duration(seconds: 5),
      );

      final client = SSHClient(
        socket,
        username: sector.username,
        onPasswordRequest: () => sector.password,
      );

      // أمر فصل كافة الماكات
      await client.run('iwpriv ath0 kickmac 00:00:00:00:00:00');
      client.close();

      setState(() {
        statusLog = 'تم فصل المشتركين بنجاح على ${sector.ip}';
      });
    } catch (e) {
      setState(() {
        statusLog = 'فشل الاتصال بـ ${sector.ip}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UBNT Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة سكتر جديد',
            onPressed: () => _showSectorDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLog,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: sectors.length,
                itemBuilder: (context, index) {
                  final sector = sectors[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        'IP: ${sector.ip}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('User: ${sector.username}'),
                      leading: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'تعديل البيانات',
                        onPressed: () => _showSectorDialog(index: index),
                      ),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: const Text('فصل'),
                        onPressed: () => disconnectClients(sector),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
