import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

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
  final List<String> sectorIps = List.generate(10, (index) => '10.181.131.${index + 1}');
  final String username = 'ubnt';
  final String password = 'ubnt0.';
  String statusLog = 'جاهز للبدء...';

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

      final result = await client.run('wstalist');
      final output = String.fromCharCodes(result);

      // disconnect command
      await client.run('iwpriv ath0 kickmac 00:00:00:00:00:00');
      client.close();

      setState(() {
        statusLog = 'تم التنفيذ بنجاح على $ip';
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
      appBar: AppBar(title: const Text('UBNT Manager')),
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
