import 'package:flutter/material.dart';

class ProvisionalTicketDialog extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const ProvisionalTicketDialog({
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

  @override
  Widget build(BuildContext context) {
    final table = ticket['table']?.toString() ?? '—';
    final date = _formatDate(ticket['date']?.toString());
    final items = (ticket['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final subtotal = (ticket['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (ticket['discount'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (ticket['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final total = (ticket['total'] as num?)?.toDouble() ?? 0.0;
    final covers = (ticket['covers'] as num?)?.toInt() ?? 1;
    final server = ticket['server']?.toString() ?? 'unknown';

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
                  const Icon(Icons.receipt_long, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TICKET PROVISOIRE',
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
                                '$name x$qty',
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
                    if (discount > 0 || discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remise ${discount > 0 ? '${discount.toStringAsFixed(0)}%' : ''}:',
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Ticket provisoire - Non encaissé',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.orange,
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

