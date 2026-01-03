import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class ConfirmPage extends StatefulWidget {
  final int orderId;
  const ConfirmPage({super.key, required this.orderId});

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  Map<String, dynamic>? order;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.dio.get('/orders/${widget.orderId}');
      setState(() => order = res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _confirm() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await ApiClient.dio.patch('/orders/${widget.orderId}/confirm');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consommation confirmée')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Confirmation')), body: Center(child: Text('Erreur: $error')));
    }
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 🆕 Support de la nouvelle structure avec mainNote/subNotes
    List<Map<String, dynamic>> items = [];
    double total = 0.0;
    
    try {
      if (order!['mainNote'] != null) {
        // Nouvelle structure
        final mainNoteData = order!['mainNote'];
        if (mainNoteData is Map<String, dynamic>) {
          final mainNote = mainNoteData;
          final mainItemsRaw = mainNote['items'];
          if (mainItemsRaw is List) {
            items = mainItemsRaw.cast<Map<String, dynamic>>();
          } else if (mainItemsRaw != null) {
            // Si ce n'est pas une List mais pas null, essayer de convertir
            items = [];
          }
          total = (mainNote['total'] as num?)?.toDouble() ?? 0.0;
          
          // Ajouter les sous-notes si présentes
          final subNotesRaw = order!['subNotes'];
          if (subNotesRaw is List) {
            for (final subNote in subNotesRaw) {
              if (subNote is Map<String, dynamic>) {
                final subNoteData = subNote;
                final subItemsRaw = subNoteData['items'];
                if (subItemsRaw is List) {
                  final subItems = subItemsRaw.cast<Map<String, dynamic>>();
                  items.addAll(subItems);
                }
                total += (subNoteData['total'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        }
      } else {
        // Ancienne structure (compatibilité)
        final itemsRaw = order!['items'];
        if (itemsRaw is List) {
          items = itemsRaw.cast<Map<String, dynamic>>();
        }
        total = (order!['total'] as num?)?.toDouble() ?? 
          items.fold<double>(0, (s, i) => s + (i['price'] as num).toDouble() * (i['quantity'] as num).toDouble());
      }
    } catch (e) {
      // En cas d'erreur, essayer de récupérer au moins les items de base
      print('[CONFIRM] Erreur lors du parsing de la commande: $e');
      final itemsRaw = order!['items'];
      if (itemsRaw is List) {
        items = itemsRaw.cast<Map<String, dynamic>>();
        total = items.fold<double>(0, (s, i) => s + (i['price'] as num).toDouble() * (i['quantity'] as num).toDouble());
      }
    }
    final confirmed = (order!['consumptionConfirmed'] as bool?) == true;
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${order!['id']} — Table ${order!['table']}')),
      body: Column(children: [
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final price = (it['price'] as num).toDouble();
              final qty = (it['quantity'] as num).toInt();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text('${it['name']} × $qty', style: const TextStyle(fontWeight: FontWeight.w600))),
                  SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('${(price * qty).toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 120),
                  const SizedBox(width: 44),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${total.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: confirmed
              ? const SizedBox.shrink()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: loading ? null : _confirm, child: Text(loading ? '...' : 'Confirmer la consommation')),
                ),
        )
      ]),
    );
  }
}



