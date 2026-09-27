import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(
    home: UbntApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class UbntApp extends StatefulWidget {
  const UbntApp({super.key});

  @override
  State<UbntApp> createState() => _UbntAppState();
}

class _UbntAppState extends State<UbntApp> {
  List<String> sectorIps = [];
  final String username = 'ubnt';
  final String password = 'ubnt0.';
  String statusLog = 'جاهز للبدء...';

  @override
  void initState() {
    super.initState();
    _loadIps();
  }

  // تحميل الأيبايات المحفوظة أو تعيين القائمة الافتراضية
  Future<void> _loadIps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sectorIps = prefs.getStringList('sector_ips') ??
          List.generate(10, (index) => '10.181.131.${index + 1}');
    });
  }

  // حفظ الأيبايات بالموبايل
  Future<void> _saveIps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sector_ips', sectorIps);
  }

  // نافذة تعديل أو إضافة IP
  void _showEditDialog({int? index}) {
    TextEditingController ipController = TextEditingController(
      text: index != null ? sectorIps[index] : '10.181.131.',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index != null ? 'تعديل IP السكتر' : 'إضافة سكتر جديد'),
        content: TextField(
          controller: ipController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'أدخل IP السكتر'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (index != null) {
                  sectorIps[index] = ipController.text;
                } else {
                  sectorIps.add(ipController.text);
                }
              });
              _saveIps();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> disconnectClients(String ip) async {
    setState(() {
      statusLog = 'جاري الاتصال بـ $ip...';
    });

    try {
      final socket = await SSHSocket.connect(ip, 22, timeout: const Duration(seconds: 5));
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.run('iwpriv ath0 kickmac 00:00:00:00:00:00');
      client.close();

      setState(() {
        statusLog = 'تم فصل المشتركين بنجاح على $ip';
      });
    } catch (e) {
      setState(() {
        statusLog = 'فشل الاتصال بـ $ip: $e';
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
            tooltip: 'إضافة سكتر',
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(statusLog, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: sectorIps.length,
                itemBuilder: (context, index) {
                  final ip = sectorIps[index];
                  return Card(
                    child: ListTile(
                      title: Text('Sector IP: $ip'),
                      leading: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(index: index),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => disconnectClients(ip),
                        child: const Text('فصل المشتركين'),
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
