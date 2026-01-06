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
      case 'CREDIT':
        return 'Crédit';
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
    final excessAmount = (ticket['excessAmount'] as num?)?.toDouble(); // 🆕 Pourboire
    final covers = (ticket['covers'] as num?)?.toInt() ?? 1;
    final server = ticket['server']?.toString() ?? 'unknown';
    final paymentMode = ticket['paymentMode']?.toString();
    final isSplitPayment = (ticket['isSplitPayment'] as bool?) ?? false;
    final paymentDetails = (ticket['paymentDetails'] as List?)?.cast<Map<String, dynamic>>() ?? []; // 🆕 Détails des paiements
    final totalAmount = (ticket['totalAmount'] as num?)?.toDouble(); // 🆕 Montant total encaissé

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 800 ? 800.0 : screenWidth * 0.95;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                          Flexible(
                            child: Text(
                              isPercentDiscount && discount > 0
                                  ? 'Remise ${discount.toStringAsFixed(0)}%:'
                                  : discount > 0 && !isPercentDiscount
                                      ? 'Remise ${_formatCurrency(discount)}:'
                                      : 'Remise:',
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    // 🆕 Afficher le pourboire si présent
                    if (excessAmount != null && excessAmount > 0.01) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Pourboire ${server.toUpperCase()}:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatCurrency(excessAmount),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 🆕 Ne pas afficher "Montant encaissé" ici car il n'est pas disponible dans le ticket
                      // Le ticket principal dans le dialog parent l'affichera correctement
                    ],
                    const SizedBox(height: 8),
                    // 🆕 Détails des paiements (modes et montants)
                    if (paymentDetails.isNotEmpty) ...[
                      const Divider(),
                      const Text(
                        'Détails des paiements:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...paymentDetails.asMap().entries.map((entry) {
                        final detail = entry.value;
                        final mode = detail['mode']?.toString() ?? 'N/A';
                        final amount = (detail['amount'] as num?)?.toDouble() ?? 0.0;
                        final clientName = detail['clientName']?.toString();
                        final isCredit = mode == 'CREDIT';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  isCredit && clientName != null && clientName.isNotEmpty
                                      ? '${_getPaymentModeLabel(mode)} ($clientName)'
                                      : _getPaymentModeLabel(mode),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: isCredit ? FontStyle.italic : FontStyle.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatCurrency(amount),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isCredit ? Colors.orange.shade700 : null,
                                  fontStyle: isCredit ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      // 🆕 Calculer et afficher le montant CREDIT non encaissé (différence entre total et montant encaissé)
                      if (total != null && totalAmount != null && total > totalAmount + 0.01) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Reste à payer:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatCurrency(total - totalAmount),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (totalAmount != null && totalAmount > 0.01) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Montant total encaissé:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatCurrency(totalAmount),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else if (paymentMode != null) ...[
                      // Fallback si paymentDetails n'est pas disponible
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
                            Flexible(
                              child: Text(
                                'Payé en ${_getPaymentModeLabel(paymentMode)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

