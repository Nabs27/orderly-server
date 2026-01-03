import 'package:flutter/material.dart';

/// Dialog de résumé avant validation du paiement
class PaymentSummaryDialog extends StatelessWidget {
  final String tableNumber;
  final String selectedNoteName;
  final double paymentTotal;
  final double finalTotal;
  final double discountAmount;
  final String? discountLabel;
  final String selectedPaymentMode;
  final String? creditClientName;
  final String? discountClientName;
  final int covers;
  final bool isPartialPayment;
  final bool isSplitPayment;
  final Map<String, double>? splitPayments;
  final Map<String, int>? splitCreditClients;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PaymentSummaryDialog({
    super.key,
    required this.tableNumber,
    required this.selectedNoteName,
    required this.paymentTotal,
    required this.finalTotal,
    required this.discountAmount,
    this.discountLabel,
    required this.selectedPaymentMode,
    this.creditClientName,
    this.discountClientName,
    required this.covers,
    this.isPartialPayment = false,
    this.isSplitPayment = false,
    this.splitPayments,
    this.splitCreditClients,
    required this.onConfirm,
    required this.onCancel,
  });

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    ) + ' TND';
  }

  String _getPaymentModeLabel(String mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
      case 'TPE':
        return 'Carte bancaire';
      case 'CHEQUE':
        return 'Chèque';
      case 'CREDIT':
        return 'Crédit client';
      case 'OFFRE':
        return 'Offre';
      default:
        return mode;
    }
  }

  IconData _getPaymentModeIcon(String mode) {
    switch (mode) {
      case 'ESPECE':
        return Icons.money;
      case 'CARTE':
      case 'TPE':
        return Icons.credit_card;
      case 'CHEQUE':
        return Icons.description;
      case 'CREDIT':
        return Icons.account_balance_wallet;
      case 'OFFRE':
        return Icons.card_giftcard;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.green.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Résumé du paiement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations table
            _buildInfoRow(
              Icons.table_restaurant,
              'Table',
              tableNumber,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            
            // Note sélectionnée
            if (selectedNoteName.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.note,
                    'Note',
                    selectedNoteName,
                    isPartialPayment ? Colors.orange : Colors.blue,
                    highlight: isPartialPayment,
                  ),
                  if (isPartialPayment)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Paiement partiel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (selectedNoteName.isNotEmpty) const SizedBox(height: 12),
            
            // Mode de paiement
            if (isSplitPayment && splitPayments != null && splitPayments!.isNotEmpty) ...[
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Paiement divisé',
                '${splitPayments!.length} mode(s)',
                Colors.blue,
              ),
              const SizedBox(height: 8),
              ...splitPayments!.entries.map((entry) {
                final mode = entry.key;
                final amount = entry.value;
                final clientId = splitCreditClients?[mode];
                return Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4),
                  child: Row(
                    children: [
                      Icon(_getPaymentModeIcon(mode), size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_getPaymentModeLabel(mode)}: ${_formatCurrency(amount)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (mode == 'CREDIT' && clientId != null)
                        Text(
                          '(Client #$clientId)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              _buildInfoRow(
                _getPaymentModeIcon(selectedPaymentMode),
                'Mode de paiement',
                _getPaymentModeLabel(selectedPaymentMode),
                Colors.green,
              ),
              if (creditClientName != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text(
                    'Client: $creditClientName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            
            // Montants
            const Divider(),
            const SizedBox(height: 12),
            _buildAmountRow('Sous-total', paymentTotal),
            if (discountAmount > 0) ...[
              const SizedBox(height: 8),
              _buildAmountRow(
                discountLabel ?? 'Remise',
                -discountAmount,
                isDiscount: true,
              ),
              if (discountClientName != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'Justification: $discountClientName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildAmountRow(
              'TOTAL À PAYER',
              finalTotal,
              isTotal: true,
            ),
            const SizedBox(height: 8),
            if (covers > 1)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Par personne: ${_formatCurrency(finalTotal / covers)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Confirmer le paiement',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlight ? color : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isDiscount = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.green.shade700 : Colors.black87,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}${_formatCurrency(amount.abs())}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isDiscount
                ? Colors.red.shade700
                : isTotal
                    ? Colors.green.shade700
                    : Colors.black87,
          ),
        ),
      ],
    );
  }
}

