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
  final List<Map<String, dynamic>>? splitPaymentTransactions; // 🆕 Liste de transactions pour calculer le pourboire
  final String? serverName; // 🆕 Nom du serveur pour afficher le pourboire
  final double? enteredAmount; // 🆕 Montant réellement saisi pour paiement scriptural simple (pour calculer le pourboire)
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
    this.splitPaymentTransactions, // 🆕 Liste de transactions
    this.serverName, // 🆕 Nom du serveur
    this.enteredAmount, // 🆕 Montant réellement saisi pour paiement scriptural simple
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
    // 🆕 Calculer le total des paiements divisés et le pourboire
    double? totalSplitAmount;
    double? tipAmount;
    bool hasCashInPayment = false;
    
    if (isSplitPayment) {
      if (splitPaymentTransactions != null && splitPaymentTransactions!.isNotEmpty) {
        totalSplitAmount = splitPaymentTransactions!.fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
        hasCashInPayment = splitPaymentTransactions!.any((t) => (t['mode'] as String) == 'ESPECE');
        // Pourboire = totalSplit - finalTotal (seulement si pas de liquide)
        if (!hasCashInPayment && totalSplitAmount! > finalTotal) {
          tipAmount = totalSplitAmount! - finalTotal;
        }
      } else if (splitPayments != null && splitPayments!.isNotEmpty) {
        totalSplitAmount = splitPayments!.values.fold<double>(0, (sum, amount) => sum + amount);
        hasCashInPayment = splitPayments!.keys.contains('ESPECE');
        if (!hasCashInPayment && totalSplitAmount! > finalTotal) {
          tipAmount = totalSplitAmount! - finalTotal;
        }
      }
    } else {
      // 🐛 BUG FIX : Calculer le pourboire pour paiement simple/partiel aussi
      // Si enteredAmount est fourni et supérieur à finalTotal, et que ce n'est pas un paiement en espèces
      if (enteredAmount != null && enteredAmount! > finalTotal && selectedPaymentMode != 'ESPECE') {
        tipAmount = enteredAmount! - finalTotal;
      }
    }
    
    return AlertDialog(
      // 🆕 Agrandir le dialog
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
            if (isSplitPayment && ((splitPaymentTransactions != null && splitPaymentTransactions!.isNotEmpty) || (splitPayments != null && splitPayments!.isNotEmpty))) ...[
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Mode de paiement',
                'SPLIT',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              // 🆕 Afficher les transactions avec leurs montants
              if (splitPaymentTransactions != null && splitPaymentTransactions!.isNotEmpty) ...[
                ...splitPaymentTransactions!.map((transaction) {
                  final mode = transaction['mode'] as String;
                  final amount = (transaction['amount'] as num).toDouble();
                  final clientName = transaction['creditClientName'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Row(
                      children: [
                        Icon(_getPaymentModeIcon(mode), size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_getPaymentModeLabel(mode)}: ${_formatCurrency(amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (mode == 'CREDIT' && clientName != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '($clientName)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ] else if (splitPayments != null && splitPayments!.isNotEmpty) ...[
                ...splitPayments!.entries.map((entry) {
                  final mode = entry.key;
                  final amount = entry.value;
                  final clientId = splitCreditClients?[mode];
                  return Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Row(
                      children: [
                        Icon(_getPaymentModeIcon(mode), size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_getPaymentModeLabel(mode)}: ${_formatCurrency(amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (mode == 'CREDIT' && clientId != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '(Client #$clientId)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
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
            // 🆕 Afficher le pourboire si présent (et pas de liquide)
            if (tipAmount != null && tipAmount! > 0.01 && serverName != null && serverName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildAmountRow(
                'POURBOIRE ${serverName!.toUpperCase()}',
                tipAmount!,
                isTotal: false,
              ),
            ],
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

