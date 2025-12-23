import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/strings.dart';

class PayConfirmPage extends StatefulWidget {
  final int billId;
  final List<Map<String, dynamic>> items;
  final double amount;
  const PayConfirmPage({super.key, required this.billId, required this.items, required this.amount});

  @override
  State<PayConfirmPage> createState() => _PayConfirmPageState();
}

class _PayConfirmPageState extends State<PayConfirmPage> {
  final payCtrl = TextEditingController();
  bool loading = false;
  int? ratingService;
  int? ratingFood;
  int? ratingWelcome;
  final noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    payCtrl.text = widget.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    payCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final amount = double.tryParse(payCtrl.text.trim()) ?? widget.amount;
      await ApiClient.dio.post('/bills/${widget.billId}/pay', data: { 'items': widget.items, 'tip': 0, 'amount': amount });
      if (!mounted) return;
      // Demander une note rapide
      await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) {
        int localWelcome = ratingWelcome ?? 0;
        int localService = ratingService ?? 0;
        int localFood = ratingFood ?? 0;
        return StatefulBuilder(builder: (context, setSheet) {
          return SafeArea(child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(Strings.t('rate_experience'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildRatingRow('Accueil', localWelcome, (v) => setSheet(() => localWelcome = v)),
              _buildRatingRow('Service', localService, (v) => setSheet(() => localService = v)),
              _buildRatingRow('Cuisine', localFood, (v) => setSheet(() => localFood = v)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () {
                setState(() {
                  ratingWelcome = localWelcome;
                  ratingService = localService;
                  ratingFood = localFood;
                });
                Navigator.pop(context);
                Navigator.pop(context, true);
              }, child: const Text('Valider')),
            ]),
          ));
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildRatingRow(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label)),
        ...List.generate(5, (i) => IconButton(
          icon: Icon(i < value ? Icons.star : Icons.star_border, color: Colors.amber),
          onPressed: () => onChanged(i + 1),
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.t('payment_confirmation'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Total à payer: ${widget.amount.toStringAsFixed(2)} TND', 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: payCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant à payer'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _submit,
              child: loading ? const CircularProgressIndicator() : const Text('Confirmer le paiement'),
            ),
          ],
        ),
      ),
    );
  }
}

