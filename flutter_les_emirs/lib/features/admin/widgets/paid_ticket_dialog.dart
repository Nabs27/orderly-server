import 'package:flutter/material.dart';

class PaidTicketDialog extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const PaidTicketDialog({
    super.key,
    required this.ticket,
  });

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return DateTime.now().toString().substring(0, 16);
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }

  String _getPaymentModeLabel(String? mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
        return 'Carte';
      case 'CHEQUE':
        return 'Chèque';
      case 'TPE':
        return 'TPE';
      default:
        return mode ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = ticket['table']?.toString() ?? '—';
    final date = _formatDate(ticket['date']?.toString());
    final items = (ticket['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final subtotal = (ticket['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (ticket['discount'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (ticket['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final isPercentDiscount = (ticket['isPercentDiscount'] as bool?) ?? false;
    final total = (ticket['total'] as num?)?.toDouble() ?? 0.0;
    final covers = (ticket['covers'] as num?)?.toInt() ?? 1;
    final server = ticket['server']?.toString() ?? 'unknown';
    final paymentMode = ticket['paymentMode']?.toString();
    final isSplitPayment = (ticket['isSplitPayment'] as bool?) ?? false;

    return Dialog(
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TICKET ENCAISSÉ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              // En-tête
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Table: $table'),
                    Text('Serveur: $server'),
                    Text('Couverts: $covers'),
                    Text('Date: $date'),
                    const SizedBox(height: 8),
                    const Divider(),
                    // Articles
                    ...items.map<Widget>((item) {
                      final name = item['name']?.toString() ?? '';
                      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                      final itemSubtotal = price * qty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$qty x $name',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              _formatCurrency(itemSubtotal),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(),
                    // Sous-total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sous-total:'),
                        Text(_formatCurrency(subtotal)),
                      ],
                    ),
                    // Remise si applicable
                    if (discountAmount > 0.01) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPercentDiscount && discount > 0
                                ? 'Remise ${discount.toStringAsFixed(0)}%:'
                                : discount > 0 && !isPercentDiscount
                                    ? 'Remise ${_formatCurrency(discount)}:'
                                    : 'Remise:',
                          ),
                          Text(
                            '-${_formatCurrency(discountAmount)}',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatCurrency(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mode de paiement
                    if (isSplitPayment) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Paiement divisé',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Payé en ${_getPaymentModeLabel(paymentMode)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

