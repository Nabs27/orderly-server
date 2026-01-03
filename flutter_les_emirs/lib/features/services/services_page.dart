import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/strings.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final tableCtrl = TextEditingController();
  bool sending = false;

  List<(String, List<(String, String)>)> get sections => [
    (
      Strings.t('services'),
      [
        ('clear', Strings.t('service_clear')),
        ('cleaning', Strings.t('service_cleaning')),
        ('ice', Strings.t('service_ice')),
        ('cutlery', Strings.t('service_cutlery')),
        ('glasses', Strings.t('service_glasses')),
      ]
    ),
  ];

  Future<void> _send(String type) async {
    final table = tableCtrl.text.trim();
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez la table')));
      return;
    }
    if (sending) return;
    setState(() => sending = true);
    try {
      await ApiClient.dio.post('/service-requests', data: { 'table': table, 'type': type });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.message}')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              const Text('Table:'),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: tableCtrl, decoration: const InputDecoration(hintText: 'Ex: A3'))),
            ]),
          ),
          ...sections.map((section) {
            final title = section.$1;
            final items = section.$2;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ExpansionTile(
                title: Text(title),
                children: [
                  ...items.map((e) {
                    final type = e.$1; final label = e.$2;
                    return ListTile(
                      title: Text(label),
                      trailing: ElevatedButton(onPressed: sending ? null : () => _send(type), child: Text(Strings.t('call'))),
                    );
                  })
                ],
              ),
            );
          })
        ],
      ),
    );
  }
}


