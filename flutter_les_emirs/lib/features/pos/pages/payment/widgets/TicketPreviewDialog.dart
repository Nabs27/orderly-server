import 'package:flutter/material.dart';

class TicketPreviewDialog extends StatelessWidget {
  final int tableNumber;
  final double paymentTotal;
  final double finalTotal;
  final double discount;
  final bool isPercentDiscount;
  final List<Map<String, dynamic>> itemsToPay;
  final bool isSplitPayment;
  final Map<String, double>? splitPayments;
  final Map<String, int>? splitCreditClients;
  final Map<String, String>? splitCreditClientNames; // 🆕 Noms des clients pour crédit

  const TicketPreviewDialog({
    super.key,
    required this.tableNumber,
    required this.paymentTotal,
    required this.finalTotal,
    required this.discount,
    required this.isPercentDiscount,
    required this.itemsToPay,
    this.isSplitPayment = false,
    this.splitPayments,
    this.splitCreditClients,
    this.splitCreditClientNames,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Debug: vérifier les valeurs reçues
    print('[TICKET] isSplitPayment: $isSplitPayment');
    print('[TICKET] splitPayments: $splitPayments');
    print('[TICKET] splitCreditClients: $splitCreditClients');
    print('[TICKET] splitCreditClientNames: $splitCreditClientNames');
    
    return AlertDialog(
      title: const Text('📄 PRÉ-ADDITION IMPRIMÉE'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête du ticket
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'LES EMIRS RESTAURANT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Table: $tableNumber'),
                    Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
                    const SizedBox(height: 8),
                    const Divider(),
                    
                    // Articles
                    ...itemsToPay.map<Widget>((it) {
                      final price = (it['price'] as num).toDouble();
                      final quantity = (it['quantity'] as num).toInt();
                      final subtotal = price * quantity;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${it['name']} x$quantity')),
                            Text('${subtotal.toStringAsFixed(2)} TND'),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const Divider(),
                    
                    // Affichage des remises si appliquées
                    if (discount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sous-total:'),
                          Text('${paymentTotal.toStringAsFixed(2)} TND'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Remise ${discount.toStringAsFixed(0)}${isPercentDiscount ? '%' : ' TND'}:'),
                          Text(
                            '-${(paymentTotal - finalTotal).toStringAsFixed(2)} TND',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                    
                    // 🆕 Afficher le total réel (paymentTotal pour paiement partiel, finalTotal pour paiement complet)
                    // Total réel de tous les articles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${finalTotal.toStringAsFixed(2)} TND',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    
                    // 🆕 Afficher les informations de paiement divisé si applicable
                    if (isSplitPayment && splitPayments != null && splitPayments!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'PAIEMENT DIVISÉ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...splitPayments!.entries.map((entry) {
                              final mode = entry.key;
                              final amount = entry.value;
                              final modeLabel = _getPaymentModeLabel(mode);
                              final isCredit = mode == 'CREDIT';
                              final clientId = isCredit && splitCreditClients != null 
                                  ? splitCreditClients![mode] 
                                  : null;
                              final clientName = isCredit && clientId != null 
                                  ? (splitCreditClientNames != null 
                                      ? (splitCreditClientNames![mode] ?? 'Client #$clientId')
                                      : 'Client #$clientId')
                                  : null;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$modeLabel${clientName != null ? ' ($clientName)' : ''}:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isCredit ? FontWeight.w600 : FontWeight.normal,
                                          color: isCredit ? Colors.orange.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${amount.toStringAsFixed(3)} TND',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCredit ? Colors.orange.shade700 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    const Text(
                      'Merci de votre visite !',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Fermer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  String _getPaymentModeLabel(String mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
        return 'Carte';
      case 'CHEQUE':
        return 'Chèque';
      case 'TPE':
        return 'TPE';
      case 'OFFRE':
        return 'Offre';
      case 'CREDIT':
        return 'Crédit';
      default:
        return mode;
    }
  }
}

