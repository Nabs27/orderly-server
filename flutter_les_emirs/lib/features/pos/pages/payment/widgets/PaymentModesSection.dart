import 'package:flutter/material.dart';

class PaymentModesSection extends StatelessWidget {
  final String selectedPaymentMode;
  final Map<String, dynamic>? selectedClientForCredit;
  final bool isSplitPayment;
  final Function(String) onPaymentModeSelected;
  final Function() onShowCreditClientDialog;
  final Function() onClearCreditClient;
  final Function()? onShowSplitPaymentDialog;

  const PaymentModesSection({
    super.key,
    required this.selectedPaymentMode,
    this.selectedClientForCredit,
    this.isSplitPayment = false,
    required this.onPaymentModeSelected,
    required this.onShowCreditClientDialog,
    required this.onClearCreditClient,
    this.onShowSplitPaymentDialog,
  });

  String _getPaymentModeTooltip(String mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Paiement en espèces';
      case 'CARTE':
        return 'Paiement par carte bancaire';
      case 'CHEQUE':
        return 'Paiement par chèque';
      case 'TPE':
        return 'Paiement par terminal de paiement électronique';
      case 'OFFRE':
        return 'Offre promotionnelle (gratuit)';
      case 'CREDIT':
        return 'Paiement à crédit (créera une dette client)';
      default:
        return mode;
    }
  }

  Widget _buildPaymentModeButton(String mode, IconData icon, Color color, bool isSelected) {
    return Tooltip(
      message: _getPaymentModeTooltip(mode),
      child: InkWell(
        onTap: () => onPaymentModeSelected(mode),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade400,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey.shade600),
                  if (isSelected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: color,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mode de paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Sélectionnez le mode de paiement utilisé par le client',
                child: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 2.2,
            children: [
              _buildPaymentModeButton('ESPECE', Icons.money, const Color(0xFF27AE60), selectedPaymentMode == 'ESPECE' && !isSplitPayment),
              _buildPaymentModeButton('CARTE', Icons.credit_card, const Color(0xFF3498DB), selectedPaymentMode == 'CARTE' && !isSplitPayment),
              _buildPaymentModeButton('CHEQUE', Icons.receipt, const Color(0xFF9B59B6), selectedPaymentMode == 'CHEQUE' && !isSplitPayment),
              _buildPaymentModeButton('TPE', Icons.payment, const Color(0xFFE67E22), selectedPaymentMode == 'TPE' && !isSplitPayment),
              _buildPaymentModeButton('OFFRE', Icons.card_giftcard, const Color(0xFFE74C3C), selectedPaymentMode == 'OFFRE' && !isSplitPayment),
              _buildPaymentModeButton('CREDIT', Icons.account_balance_wallet, const Color(0xFF34495E), selectedPaymentMode == 'CREDIT' && !isSplitPayment),
            ],
          ),
          
          // 🆕 Bouton paiement divisé
          if (onShowSplitPaymentDialog != null) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSplitPayment ? Colors.blue.withValues(alpha: 0.7) : Colors.grey.shade400,
                  width: isSplitPayment ? 2.5 : 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
                color: isSplitPayment ? Colors.blue.shade50 : Colors.grey.shade100,
                boxShadow: isSplitPayment
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: InkWell(
                onTap: onShowSplitPaymentDialog,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: isSplitPayment ? Colors.blue.withValues(alpha: 0.7) : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Paiement divisé',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSplitPayment ? Colors.blue.withValues(alpha: 0.7) : Colors.grey.shade600,
                        ),
                      ),
                      if (isSplitPayment) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

          // 🆕 Affichage du client sélectionné pour crédit
          if (selectedPaymentMode == 'CREDIT' && selectedClientForCredit != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
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
                      Icon(Icons.person, color: Colors.blue.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Client Crédit Sélectionné',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nom: ${selectedClientForCredit!['name']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Téléphone: ${selectedClientForCredit!['phone']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (selectedClientForCredit!['balance'] != null)
                    Text(
                      'Solde actuel: ${((selectedClientForCredit!['balance'] as num).toDouble()).toStringAsFixed(2)} TND',
                      style: TextStyle(
                        fontSize: 16,
                        color: ((selectedClientForCredit!['balance'] as num).toDouble()) > 0 
                          ? Colors.red 
                          : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onClearCreditClient,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Changer Client'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


