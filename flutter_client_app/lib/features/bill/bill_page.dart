import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/strings.dart';
import '../payment/pay_confirm_page.dart';

class BillPage extends StatefulWidget {
  final int billId;
  const BillPage({super.key, required this.billId});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  Map<String, dynamic>? bill;
  String? error;
  bool loading = false;

  // payment selection state: key = "orderId-itemId"
  final Map<String, int> selectedQty = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.dio.get('/bills/${widget.billId}');
      setState(() => bill = res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  double get _toPayTotal {
    if (bill == null) return 0;
    double total = 0;
    final orders = (bill!['orders'] as List).cast<Map<String, dynamic>>();
    for (final o in orders) {
      final orderId = (o['id'] as num).toInt();
      final items = (o['items'] as List).cast<Map<String, dynamic>>();
      for (final it in items) {
        final key = '$orderId-${(it['id'] as num).toInt()}';
        final qty = selectedQty[key] ?? 0;
        final price = (it['price'] as num).toDouble();
        total += qty * price;
      }
    }
    return total;
  }

  void _changeQty(int orderId, int itemId, int delta, int maxQty) {
    final key = '$orderId-$itemId';
    final current = selectedQty[key] ?? 0;
    final next = (current + delta).clamp(0, maxQty);
    setState(() => selectedQty[key] = next);
  }

  void _continueToPayment() {
    final items = <Map<String, dynamic>>[];
    selectedQty.forEach((key, qty) {
      if (qty > 0) {
        final parts = key.split('-');
        items.add({'orderId': int.parse(parts[0]), 'itemId': int.parse(parts[1]), 'quantity': qty});
      }
    });
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélection vide')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PayConfirmPage(billId: widget.billId, items: items, amount: _toPayTotal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: Text(Strings.t('bill'))), body: Center(child: Text('${Strings.t('error')}: $error')));
    }
    if (bill == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final orders = (bill!['orders'] as List).cast<Map<String, dynamic>>();
    final total = (bill!['total'] as num).toDouble();
    final paid = (bill!['paid'] as num?)?.toDouble() ?? 0;
    final remaining = (bill!['remaining'] as num?)?.toDouble() ?? (total - paid);
    return Scaffold(
      appBar: AppBar(title: Text('${Strings.t('bill')} #${bill!['id']} — ${Strings.t('table')} ${bill!['table']}')),
      body: Column(children: [
        Expanded(
          child: ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = orders[i];
              final items = (o['items'] as List).cast<Map<String, dynamic>>();
              return ExpansionTile(
                title: Text('Commande #${o['id']}'),
                initiallyExpanded: true,
                children: [
                  ...items.map((it) {
                    final orderId = (o['id'] as num).toInt();
                    final itemId = (it['id'] as num).toInt();
                    final name = it['name'] as String;
                    final price = (it['price'] as num).toDouble();
                    final maxQty = (it['quantity'] as num).toInt();
                    final key = '$orderId-$itemId';
                    final qty = selectedQty[key] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
                      child: Row(children: [
                        Expanded(child: Text('$name × $maxQty', style: const TextStyle(fontWeight: FontWeight.w600))),
                        SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('${(price * maxQty).toStringAsFixed(2)} TND'))),
                        SizedBox(
                          width: 120,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            IconButton(onPressed: () => _changeQty(orderId, itemId, -1, maxQty), icon: const Icon(Icons.remove_circle_outline)),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
                            IconButton(onPressed: () => _changeQty(orderId, itemId, 1, maxQty), icon: const Icon(Icons.add_circle_outline)),
                          ]),
                        ),
                        const SizedBox(width: 44),
                      ]),
                    );
                  })
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(Strings.t('paid')),
              const Spacer(),
              Text('${paid.toStringAsFixed(2)} TND'),
            ]),
            Row(children: [
              Text(Strings.t('remaining')),
              const Spacer(),
              Text('${remaining.toStringAsFixed(2)} TND'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Spacer(),
              Text('${Strings.t('to_pay')}: ${_toPayTotal.toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: loading ? null : _continueToPayment, child: const Text('Continuer')),
          ]),
        )
      ]),
    );
  }
}



