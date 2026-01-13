import 'package:flutter/material.dart';
import 'DiscountSection.dart';
import 'PaymentModesSection.dart';

class PaymentSection extends StatelessWidget {
  final double discount;
  final bool isPercentDiscount;
  final String selectedPaymentMode;
  final Map<String, dynamic>? selectedClientForCredit;
  final Function(double value, bool isPercent) onDiscountSelected;
  final Function(String) onPaymentModeSelected;
  final Function() onShowCreditClientDialog;
  final Function() onClearCreditClient;
  final VoidCallback onPrintNote;
  final VoidCallback onShowInvoicePreview;
  final VoidCallback onValidatePayment;
  // 🆕 Props pour le nom du client (remise)
  final String? initialClientName;
  final Function(String? clientName)? onClientNameChanged;
  // 🆕 Validation du paiement
  final bool isPaymentValid;
  final String? validationMessage;
  // 🆕 Paiement divisé
  final bool isSplitPayment;
  final Function()? onShowSplitPaymentDialog;

  const PaymentSection({
    super.key,
    required this.discount,
    required this.isPercentDiscount,
    required this.selectedPaymentMode,
    this.selectedClientForCredit,
    required this.onDiscountSelected,
    required this.onPaymentModeSelected,
    required this.onShowCreditClientDialog,
    required this.onClearCreditClient,
    required this.onPrintNote,
    required this.onShowInvoicePreview,
    required this.onValidatePayment,
    this.initialClientName,
    this.onClientNameChanged,
    this.isPaymentValid = true,
    this.validationMessage,
    this.isSplitPayment = false,
    this.onShowSplitPaymentDialog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section scrollable pour éviter le débordement
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Remise
                DiscountSection(
                  discount: discount,
                  isPercentDiscount: isPercentDiscount,
                  onDiscountSelected: onDiscountSelected,
                  initialClientName: initialClientName,
                  onClientNameChanged: onClientNameChanged,
                ),
                  
                const SizedBox(height: 16),
                  
                // Modes de paiement
                PaymentModesSection(
                  selectedPaymentMode: selectedPaymentMode,
                  selectedClientForCredit: selectedClientForCredit,
                  isSplitPayment: isSplitPayment,
                  onPaymentModeSelected: onPaymentModeSelected,
                  onShowCreditClientDialog: onShowCreditClientDialog,
                  onClearCreditClient: onClearCreditClient,
                  onShowSplitPaymentDialog: onShowSplitPaymentDialog,
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
          
        // Section fixe en bas pour les boutons d'action
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Boutons d'action rapide
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: onPrintNote,
                        icon: const Icon(Icons.print, size: 20),
                        label: const Text('PRÉ-ADDITION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: onShowInvoicePreview,
                        icon: const Icon(Icons.receipt_long, size: 20),
                        label: const Text('FACTURE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B59B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Message d'aide si paiement invalide
              if (!isPaymentValid && validationMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          validationMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Bouton principal de validation
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: isPaymentValid ? onValidatePayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaymentValid
                        ? const Color(0xFF27AE60)
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'VALIDER LE PAIEMENT',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPaymentValid ? Colors.white : Colors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

