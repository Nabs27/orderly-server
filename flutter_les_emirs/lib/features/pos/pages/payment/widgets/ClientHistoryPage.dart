import 'package:flutter/material.dart';
import '../../../../../core/api_client.dart';
import 'TicketPreviewDialog.dart';

class ClientHistoryPage extends StatefulWidget {
  final Map<String, dynamic> client;
  final Function(double amount) onPayment;

  const ClientHistoryPage({
    super.key,
    required this.client,
    required this.onPayment,
  });

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> {
  List<Map<String, dynamic>> transactions = [];
  bool loading = true;
  double balance = 0.0;

  void _showTicketPreview(Map<String, dynamic> transaction) {
    final rawTicket = transaction['ticket'];
    final ticket = (rawTicket is Map<String, dynamic> && rawTicket.isNotEmpty)
        ? rawTicket
        : _buildFallbackTicket(transaction);
    final items = ((ticket['items'] as List?) ?? [])
        .map<Map<String, dynamic>>((it) => {
              'name': it['name'] ?? 'Article',
              'price': (it['price'] as num?)?.toDouble() ?? 0.0,
              'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
            })
        .toList();
    if (items.isEmpty) {
      items.add({
        'name': transaction['description'] ?? 'Article',
        'price': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
        'quantity': 1,
      });
    }
    final double total = (ticket['total'] as num?)?.toDouble() ??
        (transaction['amount'] as num?)?.toDouble() ??
        0.0;
    final double subtotal = (ticket['subtotal'] as num?)?.toDouble() ?? total;
    final double discount = (ticket['discount'] as num?)?.toDouble() ?? 0.0;
    final bool isPercent = ticket['isPercentDiscount'] == true;
    final int tableNumber = int.tryParse('${ticket['table'] ?? transaction['table'] ?? 0}') ?? 0;

    showDialog(
      context: context,
      builder: (_) => TicketPreviewDialog(
        tableNumber: tableNumber,
        paymentTotal: subtotal,
        finalTotal: total,
        discount: discount,
        isPercentDiscount: isPercent,
        itemsToPay: items,
      ),
    );
  }

  Map<String, dynamic> _buildFallbackTicket(Map<String, dynamic> transaction) {
    final total = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    return {
      'table': transaction['table'] ?? '-',
      'date': transaction['date'] ?? DateTime.now().toIso8601String(),
      'items': [
        {
          'name': transaction['description'] ?? 'Article',
          'quantity': 1,
          'price': total,
        }
      ],
      'total': total,
      'subtotal': total,
      'discount': 0.0,
      'isPercentDiscount': false,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadClientHistory();
  }

  Future<void> _loadClientHistory() async {
    try {
      final response = await ApiClient.dio.get('/api/credit/clients/${widget.client['id']}');
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          transactions = List<Map<String, dynamic>>.from(data['transactions']);
          balance = (data['balance'] as num).toDouble();
          loading = false;
        });
      }
    } catch (e) {
      print('[CREDIT] Erreur chargement historique: $e');
      setState(() => loading = false);
    }
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController();
    String selectedMode = 'ESPECE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Paiement Client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMode,
                decoration: const InputDecoration(
                  labelText: 'Mode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ESPECE', child: Text('Espèces')),
                  DropdownMenuItem(value: 'CARTE', child: Text('Carte')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Chèque')),
                ],
                onChanged: (value) => setDialogState(() => selectedMode = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.of(context).pop();
                  await _processPayment(amount, selectedMode);
                }
              },
              child: const Text('Payer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(double amount, String paymentMode) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/credit/clients/${widget.client['id']}/pay-oldest',
        data: {
          'amount': amount,
          'paymentMode': paymentMode,
        },
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message'] ?? 'Paiement effectué'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadClientHistory();
      }
    } catch (e) {
      print('[CREDIT] Erreur paiement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur paiement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique - ${widget.client['name']}'),
        backgroundColor: const Color(0xFF2C3E50),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: balance > 0 ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${balance.toStringAsFixed(2)} TND',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: balance > 0 ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          balance > 0 ? Icons.warning : Icons.check_circle,
                          color: balance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.client['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(widget.client['phone']),
                            Text(
                              balance > 0 ? 'Dette: ${balance.toStringAsFixed(2)} TND' : 'Crédit: ${(-balance).toStringAsFixed(2)} TND',
                              style: TextStyle(
                                color: balance > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showPaymentDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34495E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Payer'),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'DATE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'DESCRIPTION',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'DÉBIT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'CRÉDIT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'SOLDE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final reversedIndex = transactions.length - 1 - index;
                            final transaction = transactions[reversedIndex];
                            final isDebit = transaction['type'] == 'DEBIT';
                            final amount = (transaction['amount'] as num).toDouble();
                            final date = DateTime.parse(transaction['date']);

                            final hasTicket = transaction['ticket'] != null || transaction['type'] == 'DEBIT';
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${date.day}/${date.month}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        transaction['description'],
                                        style: const TextStyle(fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        isDebit ? amount.toStringAsFixed(2) : '',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        !isDebit ? amount.toStringAsFixed(2) : '',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Builder(
                                        builder: (context) {
                                          final runningBalance = transaction['runningBalance'] != null 
                                            ? (transaction['runningBalance'] as num).toDouble() 
                                            : null;
                                          final balanceValue = runningBalance ?? 0.0;
                                          return Text(
                                            runningBalance != null ? balanceValue.toStringAsFixed(2) : '',
                                            style: TextStyle(
                                              color: balanceValue > 0 ? Colors.red : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            textAlign: TextAlign.right,
                                          );
                                        },
                                      ),
                                    ),
                                    if (hasTicket)
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long, size: 20),
                                        tooltip: 'Voir ticket',
                                        onPressed: () => _showTicketPreview(transaction),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                          border: Border.all(
                            color: balance > 0 ? Colors.red.shade300 : Colors.green.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'SOLDE FINAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${balance.toStringAsFixed(2)} TND',
                                  style: TextStyle(
                                    color: balance > 0 ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

