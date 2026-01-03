import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

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
      // 1) Demander une note rapide d'abord
      await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) {
        int localWelcome = ratingWelcome ?? 0;
        int localService = ratingService ?? 0;
        int localFood = ratingFood ?? 0;
        return StatefulBuilder(builder: (context, setSheet) {
          return SafeArea(child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Notez votre expérience'),
              const SizedBox(height: 8),
              _ratingRow('Accueil', localWelcome, (v){ setSheet(()=> localWelcome = v); }),
              const SizedBox(height: 8),
              _ratingRow('Service', localService, (v){ setSheet(()=> localService = v); }),
              const SizedBox(height: 8),
              _ratingRow('Nourriture', localFood, (v){ setSheet(()=> localFood = v); }),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Une remarque ? (optionnel)')),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: (){
                setState(() { ratingWelcome = localWelcome; ratingService = localService; ratingFood = localFood; });
                Navigator.pop(context);
              }, child: const Text('Envoyer')),
            ]),
          ));
        });
      });
      if (!mounted) return;
      // 2) Remercier puis retour automatique (fermeture auto du dialog)
      // Afficher le dialog sans attendre une action utilisateur
      // puis le fermer après 1s et revenir à l'accueil
      // (rootNavigator pour être sûr de fermer le dialog en priorité)
      //
      // Afficher
      // (ne pas attendre ici sinon il ne se ferme jamais)
      //
      // ignore: use_build_context_synchronously
      showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(
        title: Text('Merci!'),
        content: Text('Merci pour votre visite. Vos retours nous aident à nous améliorer. 😊'),
      ));
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // fermer le dialog
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst); // retour accueil
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _ratingRow(String label, int selected, void Function(int) onSelect) {
    return Row(children: [
      Expanded(child: Text(label)),
      for (int i=1;i<=5;i++) IconButton(
        onPressed: () => onSelect(i),
        icon: Icon(i <= selected ? Icons.star : Icons.star_border, color: i <= selected ? Colors.amber : Colors.grey),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Montant à payer: ${widget.amount.toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: payCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Montant donné par le client'),
            onTap: () { payCtrl.clear(); },
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: loading ? null : _submit, child: Text(loading ? '...' : 'Valider le paiement')),
        ]),
      ),
    );
  }
}


