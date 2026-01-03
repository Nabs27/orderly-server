import 'package:flutter/material.dart';
import '../../../models/order_note.dart';
import 'NoteSelectionSection.dart';
import 'ItemsDetailSection.dart';
import 'TotalsSection.dart';

class PaymentLeftPanel extends StatelessWidget {
  final String selectedNoteForPayment;
  final double total;
  final double totalForAll; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer" (toujours depuis getAllItemsOrganized)
  final double totalForMain; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
  final double totalForPartial; // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
  final OrderNote mainNote;
  final List<OrderNote> subNotes;
  final Color Function(String) getNoteColor;
  final Function(String) onNoteSelected;
  final List<Map<String, dynamic>> itemsToShow;
  final double paymentTotal;
  final double finalTotal;
  final double discount;
  final bool isPercentDiscount;
  final String tableNumber;
  final int covers;
  final String? serverName;
  final Map<String, double> subNoteTotals; // 🆕 Totaux calculés depuis _getAllItemsOrganized()

  const PaymentLeftPanel({
    super.key,
    required this.selectedNoteForPayment,
    required this.total,
    required this.totalForAll, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer"
    required this.totalForMain, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
    required this.totalForPartial, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
    required this.mainNote,
    required this.subNotes,
    required this.getNoteColor,
    required this.onNoteSelected,
    required this.itemsToShow,
    required this.paymentTotal,
    required this.finalTotal,
    required this.discount,
    required this.isPercentDiscount,
    required this.tableNumber,
    required this.covers,
    this.serverName,
    required this.subNoteTotals, // 🆕 Totaux calculés depuis _getAllItemsOrganized()
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 🆕 CORRECTION : Supprimer TableInfoCard (infos maintenant dans AppBar)
          // Sélection des notes pour paiement (agrandie)
          NoteSelectionSection(
            selectedNoteForPayment: selectedNoteForPayment,
            total: total,
            totalForAll: totalForAll, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer"
            totalForMain: totalForMain, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
            totalForPartial: totalForPartial, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
            mainNote: mainNote,
            subNotes: subNotes,
            getNoteColor: getNoteColor,
            onNoteSelected: onNoteSelected,
            subNoteTotals: subNoteTotals, // 🆕 Utiliser les totaux calculés
          ),
          
          // Détail des articles de la note sélectionnée
          Expanded(
            child: ItemsDetailSection(
              itemsToShow: itemsToShow,
              selectedNoteForPayment: selectedNoteForPayment,
            ),
          ),
          
          // Totaux et options
          TotalsSection(
            paymentTotal: paymentTotal,
            finalTotal: finalTotal,
            discount: discount,
            isPercentDiscount: isPercentDiscount,
          ),
        ],
      ),
    );
  }
}

