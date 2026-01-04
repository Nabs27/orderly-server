import 'package:flutter/material.dart';
import '../../../models/order_note.dart';
import '../../../widgets/pos_numpad.dart';

class PosOrderActionPanel extends StatelessWidget {
  final OrderNote activeNote;
  final int? selectedLineIndex;
  final Function() onSendToKitchen;
  final bool sendingOrder;
  final Function(int) onNumberPressed;
  final Function() onClear;
  final Function() onCancel;
  final Function() onNote;
  final Function() onIngredient;
  final Function() onBack;
  final Function() onShowTransferServerDialog;
  final Function() onOpenDebtSettlement;
  final Function() onShowTransferDialog;
  final Function() onShowTransferToTableDialog;
  final Function() onOpenPayment;
  final Function(int)? onQuantityEntered; // 🆕 Callback pour quantité saisie
  final Map<String, dynamic>? pendingItemForQuantity; // 🆕 Article en attente de quantité

  const PosOrderActionPanel({
    super.key,
    required this.activeNote,
    required this.selectedLineIndex,
    required this.onSendToKitchen,
    this.sendingOrder = false,
    required this.onNumberPressed,
    required this.onClear,
    required this.onCancel,
    required this.onNote,
    required this.onIngredient,
    required this.onBack,
    required this.onShowTransferServerDialog,
    required this.onOpenDebtSettlement,
    required this.onShowTransferDialog,
    required this.onShowTransferToTableDialog,
    required this.onOpenPayment,
    this.onQuantityEntered, // 🆕 Optionnel
    this.pendingItemForQuantity, // 🆕 Optionnel
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Container(
        color: const Color(0xFF34495E),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Bouton COMMANDE
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                onPressed: sendingOrder ? null : onSendToKitchen,
                icon: const Icon(Icons.send, size: 32),
                label: Text(
                  sendingOrder ? 'ENVOI...' : 'COMMANDE',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF39C12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Pavé numérique + actions (optimisé pour tactile)
            Expanded(
              child: PosNumpad(
                onNumberPressed: onNumberPressed,
                onClear: onClear,
                onCancel: onCancel,
                onNote: onNote,
                onIngredient: onIngredient,
                onBack: onBack,
                onQuantityEntered: onQuantityEntered, // 🆕 Callback pour quantité
                enableQuantityMode: pendingItemForQuantity != null, // 🆕 Activer si article en attente
              ),
            ),

            const SizedBox(height: 8),

            // Boutons compacts: Transfert Serveur + Dette (global)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: onShowTransferServerDialog,
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      label: const Text('Serveur', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF39C12),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: onOpenDebtSettlement,
                      icon: const Icon(Icons.account_balance_wallet, size: 20),
                      label: const Text('Dette', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34495E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Boutons de transfert (optimisés pour tactile)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: activeNote.items.isEmpty ? null : onShowTransferDialog,
                      icon: const Icon(Icons.swap_horiz, size: 24),
                      label: const Text('Note', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: activeNote.items.isEmpty ? null : onShowTransferToTableDialog,
                      icon: const Icon(Icons.swap_horiz, size: 24),
                      label: const Text('Table', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bouton paiement (agrandi pour tactile)
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                onPressed: activeNote.items.isEmpty ? null : onOpenPayment,
                icon: const Icon(Icons.payment, size: 32),
                label: const Text('ENCAISSER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

