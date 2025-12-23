import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final tableCtrl = TextEditingController();
  List<Map<String, dynamic>> orders = [];
  String? error;
  double runningTotal = 0;

  Future<void> _load() async {
    final table = tableCtrl.text.trim();
    if (table.isEmpty) {
      setState(() { orders = []; runningTotal = 0; error = null; });
      return;
    }
    try {
      final res = await ApiClient.dio.get('/orders', queryParameters: {'table': table});
      final list = (res.data as List).cast<Map<String, dynamic>>();
      list.sort((a,b)=> DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
      final total = list.fold<double>(0.0, (double s, Map<String, dynamic> o) {
        final t = (o['total'] as num?);
        return s + ((t?.toDouble()) ?? 0.0);
      });
      setState(() { orders = list; runningTotal = total; error = null; });
    } on DioException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            const Text('Table:'),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: tableCtrl, onSubmitted: (_) => _load(), decoration: const InputDecoration(hintText: 'Ex: A3'))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _load, child: const Text('Charger')),
          ]),
        ),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text('Erreur: $error')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(children: [
            const Text('Total à payer (cumulé):'),
            const Spacer(),
            Text('${runningTotal.toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final items = (o['items'] as List).cast<Map<String, dynamic>>();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  title: Text('#${o['id']} • ${DateTime.parse(o['createdAt']).toLocal().toString().substring(11,16)} • ${(o['total'] as num?)?.toStringAsFixed(2) ?? '0.00'} TND • ${o['consumptionConfirmed'] == true ? 'Confirmée' : 'En attente'}'),
                  children: [
                    ...items.map((it) => ListTile(
                      title: Text('${it['name']} × ${it['quantity']}'),
                      trailing: Text('${((it['price'] as num) * (it['quantity'] as num)).toStringAsFixed(2)} TND'),
                    )),
                    if ((o['notes'] as String?)?.isNotEmpty == true)
                      Padding(padding: const EdgeInsets.all(12), child: Text('📝 ${o['notes']}')),
                    ButtonBar(alignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () { Navigator.pushNamed(context, '/confirm/${o['id']}'); }, child: const Text('Ouvrir')),
                    ])
                  ],
                ),
              );
            },
          ),
        )
      ]),
    );
  }
}


