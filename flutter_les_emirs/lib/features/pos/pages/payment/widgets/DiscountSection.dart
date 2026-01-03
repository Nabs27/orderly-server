import 'package:flutter/material.dart';
import 'DiscountClientNameDialog.dart';

class DiscountSection extends StatefulWidget {
  final double discount;
  final bool isPercentDiscount;
  final Function(double value, bool isPercent) onDiscountSelected;
  final String? initialClientName; // 🆕 Nom initial (ex: nom de la sous-note)
  final Function(String? clientName)? onClientNameChanged; // 🆕 Callback pour notifier le parent

  const DiscountSection({
    super.key,
    required this.discount,
    required this.isPercentDiscount,
    required this.onDiscountSelected,
    this.initialClientName,
    this.onClientNameChanged,
  });

  @override
  State<DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends State<DiscountSection> {
  Future<void> _handleDiscountSelection(double value, bool isPercent) async {
    // Si c'est "AUCUNE" (value = 0), pas de dialog
    if (value == 0) {
      widget.onDiscountSelected(value, isPercent);
      return;
    }

    // 🆕 Pour toute remise > 0, ouvrir automatiquement le dialog
    final result = await showGeneralDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        return DiscountClientNameDialog(
          initialClientName: widget.initialClientName,
        );
      },
    );

    // 🆕 Notifier le parent du nom du client
    if (widget.onClientNameChanged != null) {
      widget.onClientNameChanged!(result);
    }

    // Appliquer la remise sélectionnée
    widget.onDiscountSelected(value, isPercent);
  }

  Widget _buildDiscountButton(String label, double value, bool isPercent, bool isSelected) {
    final isNoDiscount = label == 'AUCUNE';
    final tooltip = isNoDiscount
        ? 'Aucune remise'
        : 'Remise de $label';
    
    return Tooltip(
      message: tooltip,
      child: SizedBox(
      height: 50,
      child: ElevatedButton(
          onPressed: () => _handleDiscountSelection(value, isPercent),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected 
              ? Colors.orange.shade600 
              : isNoDiscount 
                  ? Colors.grey.shade300 
                  : Colors.orange.shade100,
          foregroundColor: isSelected 
              ? Colors.white 
              : isNoDiscount 
                  ? Colors.grey.shade700 
                  : Colors.orange.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: isSelected ? 4 : 1,
            side: isSelected
                ? BorderSide(color: Colors.orange.shade800, width: 2)
                : null,
        ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 16, color: Colors.white),
              ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
            children: [
              const Text(
                'Remise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Appliquez une remise en pourcentage. Vous devrez saisir le nom du client pour justifier la remise.',
                    child: Icon(
                      Icons.help_outline,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (widget.discount > 0) ...[
                Tooltip(
                  message: widget.discount > 20
                      ? 'Remise importante (${widget.discount.toStringAsFixed(0)}%)'
                      : 'Remise de ${widget.discount.toStringAsFixed(0)}%',
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: widget.discount > 20
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.discount > 20
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                        width: widget.discount > 20 ? 2 : 1,
                      ),
                  ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.discount > 20)
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                        if (widget.discount > 20) const SizedBox(width: 4),
                        Text(
                          '${widget.discount.toStringAsFixed(0)}${widget.isPercentDiscount ? '%' : ' TND'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                            color: widget.discount > 20
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Boutons de remise tactiles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDiscountButton('5%', 5, true, widget.discount == 5 && widget.isPercentDiscount),
              _buildDiscountButton('10%', 10, true, widget.discount == 10 && widget.isPercentDiscount),
              _buildDiscountButton('15%', 15, true, widget.discount == 15 && widget.isPercentDiscount),
              _buildDiscountButton('20%', 20, true, widget.discount == 20 && widget.isPercentDiscount),
              _buildDiscountButton('25%', 25, true, widget.discount == 25 && widget.isPercentDiscount),
              _buildDiscountButton('30%', 30, true, widget.discount == 30 && widget.isPercentDiscount),
              _buildDiscountButton('50%', 50, true, widget.discount == 50 && widget.isPercentDiscount),
              _buildDiscountButton('AUCUNE', 0, true, widget.discount == 0),
            ],
          ),
          
          // 🆕 Bouton "Nom du client" (optionnel, visible uniquement si remise > 0)
          // Permet de modifier le nom si déjà saisi
          if (widget.discount > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // 🆕 Ouvrir le dialog pour modifier le nom du client
                  final result = await showGeneralDialog<String?>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                    barrierColor: Colors.black54,
                    transitionDuration: const Duration(milliseconds: 200),
                    pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
                      return DiscountClientNameDialog(
                        initialClientName: widget.initialClientName,
                      );
                    },
                  );
                  
                  // 🆕 Notifier le parent du résultat
                  if (widget.onClientNameChanged != null) {
                    widget.onClientNameChanged!(result);
                  }
                },
                icon: Icon(
                  widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                      ? Icons.person
                      : Icons.person_outline,
                  color: widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                      ? Colors.orange.shade700
                      : Colors.grey.shade600,
                ),
                label: Text(
                  widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                      ? widget.initialClientName!
                      : 'Modifier le nom du client',
                  style: TextStyle(
                    color: widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                        ? Colors.orange.shade700
                        : Colors.grey.shade700,
                    fontWeight: widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  side: BorderSide(
                    color: widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: widget.initialClientName != null && widget.initialClientName!.isNotEmpty
                      ? Colors.orange.shade50
                      : Colors.grey.shade50,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

