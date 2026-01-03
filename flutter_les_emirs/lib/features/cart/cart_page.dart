import 'package:flutter/material.dart';
import '../../core/cart_service.dart';
import '../../core/strings.dart';
import '../../core/api_client.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final cart = CartService.instance;
  final tableCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    cart.load();
    notesCtrl.text = cart.notes;
    tableCtrl.text = cart.tableCode;
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    tableCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t('your_cart')),
        actions: [
          IconButton(
            tooltip: 'Vider le panier',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Vider le panier ?'),
                  content: const Text('Cette action supprimera tous les articles.'),
                  actions: [
                    TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text('Annuler')),
                    ElevatedButton(onPressed: ()=> Navigator.pop(context, true), child: const Text('Confirmer')),
                  ],
                ),
              );
              if (confirm == true) {
                await cart.clear();
                setState((){});
              }
            },
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: cart.items,
        builder: (context, list, _) {
          return Column(
            children: [
              if (cart.lastOrderId != null) _PreviousOrderCard(
                orderId: cart.lastOrderId!,
                total: cart.lastOrderTotal ?? 0,
                createdAtIso: cart.lastOrderAt,
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(children: [
                  Text('${Strings.t('table') }:'),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: tableCtrl, decoration: const InputDecoration(hintText: 'Ex: A3'), onChanged: (v) async { cart.tableCode = v; await cart.save(); })),
                ]),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                  child: ListView.separated(
                    key: ValueKey('cart-${list.length}-${cart.total}'),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = list[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(children: [
                          Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('${it.price.toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)))),
                          SizedBox(
                            width: 120,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              IconButton(onPressed: () async { await cart.updateQty(it.id, -1); setState((){}); }, icon: const Icon(Icons.remove_circle_outline)),
                              Text('${it.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              IconButton(onPressed: () async { await cart.updateQty(it.id, 1); setState((){}); }, icon: const Icon(Icons.add_circle_outline)),
                            ]),
                          ),
                          SizedBox(width: 44, child: IconButton(onPressed: () async { await cart.remove(it.id); setState((){}); }, icon: const Icon(Icons.close))),
                        ]),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: Strings.t('notes')),
                  onChanged: (v) async { cart.notes = v; await cart.save(); },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                child: Row(children: [
                  Text('${Strings.t('total')}:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${cart.total.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(children: [
                  if (cart.lastOrderId != null)
                    Expanded(child: OutlinedButton(onPressed: _requestBill, child: Text(Strings.t('request_bill'))))
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _submit, child: Text(Strings.t('validate_order')))),
                ]),
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final table = tableCtrl.text.trim();
    if (table.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez la table')));
      return;
    }
    final items = cart.items.value.map((e) => { 'id': e.id, 'name': e.name, 'price': e.price, 'quantity': e.quantity }).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Panier vide')));
      return;
    }
    try {
      final res = await ApiClient.dio.post('/orders', data: { 'table': table, 'items': items, 'notes': cart.notes });
      final data = res.data as Map<String, dynamic>;
      // Enregistrer la dernière commande et vider le panier
      await cart.recordLastOrder(
        id: (data['id'] as num).toInt(),
        total: ((data['total'] as num?)?.toDouble() ?? cart.total),
        createdAt: (data['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      );
      await cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/confirm/${data['id']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _requestBill() async {
    final table = tableCtrl.text.trim();
    if (table.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${Strings.t('fill_table')}')));
      }
      return;
    }
    if (cart.lastOrderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.t('no_previous_order'))));
      }
      return;
    }
    try {
      final res = await ApiClient.dio.post('/bills', data: { 'table': table });
      final bill = res.data as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushNamed('/bill/${bill['id']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}
class _PreviousOrderCard extends StatelessWidget {
  final int orderId;
  final double total;
  final String? createdAtIso;
  const _PreviousOrderCard({required this.orderId, required this.total, required this.createdAtIso});

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return '';
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Strings.t('previous_order'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${_formatTime(createdAtIso)}  •  ${total.toStringAsFixed(2)} TND'),
        ])),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/confirm/$orderId'),
          child: Text(Strings.t('details')),
        )
      ]),
    );
  }
}


