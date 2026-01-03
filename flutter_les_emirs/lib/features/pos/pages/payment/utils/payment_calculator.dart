import '../../../models/order_note.dart';

/// Helper pour les calculs de paiement (totaux, remises, etc.)
/// 
/// 🆕 SOURCE DE VÉRITÉ UNIQUE :
/// - Utilise organizedItemsForPartialPayment et getAllItemsOrganized() qui viennent
///   de _currentAllOrders (données backend) en priorité
/// - Ne calcule plus unpaidQuantity depuis mainNote.items pour éviter la désynchronisation
/// - Les paramètres mainNote et subNotes sont conservés pour compatibilité mais non utilisés pour les calculs
class PaymentCalculator {
  /// Calcule le total de paiement selon la sélection
  /// 🆕 SOURCE DE VÉRITÉ UNIQUE : Utilise organizedItemsForPartialPayment qui vient de _currentAllOrders (backend)
  static double calculatePaymentTotal({
    required String selectedNoteForPayment,
    required OrderNote mainNote, // ⚠️ Conservé pour compatibilité mais non utilisé pour les calculs
    required List<OrderNote> subNotes, // ⚠️ Conservé pour compatibilité mais non utilisé pour les calculs
    required Map<int, int> selectedPartialQuantities,
    required List<Map<String, dynamic>> organizedItemsForPartialPayment, // 🆕 Source de vérité unique
    required List<Map<String, dynamic>> Function() getAllItemsOrganized, // 🆕 Pour obtenir tous les items (all + sub)
  }) {
    if (selectedNoteForPayment == 'all') {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser getAllItemsOrganized() qui vient de _currentAllOrders
      final allItems = getAllItemsOrganized();
      return allItems.fold(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0; // Déjà unpaidQuantity
        return sum + (price * quantity);
      });
    } else if (selectedNoteForPayment == 'main') {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser organizedItemsForPartialPayment filtré pour la note principale
      // 🎯 On ne compte que les quantités appartenant à la note principale au sein des articles groupés
      return organizedItemsForPartialPayment.fold(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        int quantity = 0;
        
        final sources = item['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          quantity = sources
              .where((s) => (s as Map<String, dynamic>)['noteId'] == 'main' || s['noteId'] == null)
              .fold<int>(0, (s, src) => s + ((src as Map<String, dynamic>)['quantity'] as int? ?? 0));
        } else {
          quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        }
        return sum + (price * quantity);
      });
    } else if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isNotEmpty) {
      // Paiement partiel : somme des articles sélectionnés depuis organizedItemsForPartialPayment
      return selectedPartialQuantities.entries.fold(0.0, (sum, entry) {
        final itemId = entry.key;
        final quantity = entry.value;
        final item = organizedItemsForPartialPayment.firstWhere(
          (it) => it['id'] == itemId,
          orElse: () => {'price': 0.0},
        );
        return sum + ((item['price'] as num).toDouble() * quantity);
      });
    } else if (selectedNoteForPayment.startsWith('sub_')) {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser getAllItemsOrganized() filtré pour la sous-note
      final allItems = getAllItemsOrganized();
      
      return allItems.fold(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        int quantity = 0;
        
        final sources = item['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          // 🎯 On ne compte que les quantités appartenant à la sous-note sélectionnée
          quantity = sources
              .where((s) => (s as Map<String, dynamic>)['noteId'] == selectedNoteForPayment)
              .fold<int>(0, (s, src) => s + ((src as Map<String, dynamic>)['quantity'] as int? ?? 0));
        } else if (item['noteId'] == selectedNoteForPayment) {
          quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        }
        return sum + (price * quantity);
      });
    } else {
      // Fallback : retourner 0 si cas non géré
      return 0.0;
    }
  }

  /// Calcule le total final après remise
  static double calculateFinalTotal({
    required double paymentTotal,
    required double discount,
    required bool isPercentDiscount,
  }) {
    if (discount == 0) {
      return paymentTotal;
    }
    
    if (isPercentDiscount) {
      return paymentTotal * (1 - discount / 100);
    } else {
      return (paymentTotal - discount).clamp(0.0, double.infinity);
    }
  }

  /// Calcule le montant par personne
  static double calculateAmountPerPerson({
    required double finalTotal,
    required int covers,
  }) {
    return covers > 0 ? finalTotal / covers : finalTotal;
  }
}

