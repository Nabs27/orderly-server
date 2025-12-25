import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/keyboards/numeric_keyboard.dart';

class PaymentModesSection extends StatefulWidget {
  final String selectedPaymentMode;
  final Map<String, dynamic>? selectedClientForCredit;
  final bool isSplitPayment;
  final Function(String) onPaymentModeSelected;
  final Function() onShowCreditClientDialog;
  final Function() onClearCreditClient;
  // 🆕 Paiement divisé
  final Function()? onShowSplitPaymentDialog;
  // 🆕 Pourboire scriptural
  final TextEditingController? receivedController;
  final FocusNode? receivedFocusNode;
  final double tipAmount;
  final bool hasCheckInfo;
  final Function()? onAddCheckInfo;

  const PaymentModesSection({
    super.key,
    required this.selectedPaymentMode,
    this.selectedClientForCredit,
    this.isSplitPayment = false,
    required this.onPaymentModeSelected,
    required this.onShowCreditClientDialog,
    required this.onClearCreditClient,
    this.onShowSplitPaymentDialog,
    this.receivedController,
    this.receivedFocusNode,
    this.tipAmount = 0,
    this.hasCheckInfo = false,
    this.onAddCheckInfo,
  });

  @override
  State<PaymentModesSection> createState() => _PaymentModesSectionState();
}

class _PaymentModesSectionState extends State<PaymentModesSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mode de paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              if (widget.isSplitPayment)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_split, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'DIVISÉ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              _buildPaymentModeButton('ESPECE', Icons.money, const Color(0xFF27AE60)),
              _buildPaymentModeButton('CARTE', Icons.credit_card, const Color(0xFF3498DB)),
              _buildPaymentModeButton('CHEQUE', Icons.receipt, const Color(0xFF9B59B6)),
              _buildPaymentModeButton('TPE', Icons.payment, const Color(0xFFE67E22)),
              _buildPaymentModeButton('OFFRE', Icons.card_giftcard, const Color(0xFFE74C3C)),
              _buildPaymentModeButton('CREDIT', Icons.account_balance_wallet, const Color(0xFF34495E)),
            ],
          ),

          if (!widget.isSplitPayment) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onShowSplitPaymentDialog,
                icon: const Icon(Icons.call_split),
                label: const Text('PASSER EN PAIEMENT DIVISÉ (SPLIT)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],

          // 🆕 Champ montant reçu et CLAVIER INLINE
          if (!widget.isSplitPayment && (widget.selectedPaymentMode == 'TPE' || widget.selectedPaymentMode == 'CHEQUE' || widget.selectedPaymentMode == 'ESPECE')) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (widget.selectedPaymentMode == 'ESPECE') ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (widget.selectedPaymentMode == 'ESPECE') ? Colors.green.shade200 : Colors.orange.shade200,
                  width: 2
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (widget.selectedPaymentMode == 'ESPECE') ? 'ESPÈCES REÇUES' : 'MONTANT RÉEL TICKET', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: (widget.selectedPaymentMode == 'ESPECE') ? Colors.green.shade700 : Colors.orange.shade800
                        ),
                      ),
                      if (widget.receivedController != null && widget.receivedController!.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.backspace_outlined),
                          onPressed: () {
                            final text = widget.receivedController!.text;
                            if (text.isNotEmpty) {
                              widget.receivedController!.text = text.substring(0, text.length - 1);
                            }
                          },
                          color: (widget.selectedPaymentMode == 'ESPECE') ? Colors.green : Colors.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Affichage du montant en gros
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      widget.receivedController?.text.isEmpty ?? true 
                          ? '0.000' 
                          : widget.receivedController!.text,
                      style: const TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Aide contextuelle (Rendu ou Pourboire)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.selectedPaymentMode == 'ESPECE' && widget.tipAmount < 0)
                        Text(
                          'RENDU : ${(-widget.tipAmount).toStringAsFixed(3)} TND',
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                        )
                      else if (widget.tipAmount > 0)
                        Text(
                          'POURBOIRE : ${widget.tipAmount.toStringAsFixed(3)} TND',
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                        )
                      else 
                        Text(
                          'Saisir le montant reçu...',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // CLAVIER NUMÉRIQUE INLINE (Ergonomie POS)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: NumericKeyboard(
                        showDecimal: true,
                        onKeyPressed: (key) {
                          if (widget.receivedController != null) {
                            // Empêcher plusieurs points décimaux
                            if (key == '.' && widget.receivedController!.text.contains('.')) return;
                            widget.receivedController!.text += key;
                          }
                        },
                        onBackspace: () {
                          if (widget.receivedController != null && widget.receivedController!.text.isNotEmpty) {
                            final text = widget.receivedController!.text;
                            widget.receivedController!.text = text.substring(0, text.length - 1);
                          }
                        },
                        onClear: () {
                          widget.receivedController?.clear();
                        },
                      ),
                    ),
                  ),
                  
                  if (widget.selectedPaymentMode == 'CHEQUE') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: widget.onAddCheckInfo,
                        icon: Icon(Icons.edit_note, color: widget.hasCheckInfo ? Colors.white : Colors.purple),
                        label: Text(
                          widget.hasCheckInfo ? 'INFOS CHÈQUE ENREGISTRÉES' : 'CONFIGURER LES INFOS DU CHÈQUE',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.hasCheckInfo ? Colors.purple : Colors.purple.shade50,
                          foregroundColor: widget.hasCheckInfo ? Colors.white : Colors.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeButton(String mode, IconData icon, Color color) {
    final bool isSelected = widget.selectedPaymentMode == mode && !widget.isSplitPayment;
    final hasClient = mode == 'CREDIT' && widget.selectedClientForCredit != null;
    final label = hasClient ? widget.selectedClientForCredit!['name'] : _getModeName(mode);

    return InkWell(
      onTap: () => widget.onPaymentModeSelected(mode),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (mode == 'CREDIT' && isSelected && hasClient)
              GestureDetector(
                onTap: widget.onClearCreditClient,
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.cancel, size: 14, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getModeName(String mode) {
    switch (mode) {
      case 'ESPECE': return 'ESPÈCES';
      case 'CARTE': return 'CARTE';
      case 'CHEQUE': return 'CHÈQUE';
      case 'TPE': return 'BANQUE TPE';
      case 'OFFRE': return 'OFFERT';
      case 'CREDIT': return 'CRÉDIT';
      default: return mode;
    }
  }
}
