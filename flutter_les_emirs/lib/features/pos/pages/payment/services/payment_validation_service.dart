import 'package:flutter/material.dart';
import '../../../models/order_note.dart';
import 'payment_service.dart';

/// Service pour valider et traiter les paiements
/// 
/// 🆕 SOURCE DE VÉRITÉ UNIQUE :
/// - Les données de paiement (unpaidQuantity) viennent toujours de getAllItemsOrganized()
///   qui utilise _currentAllOrders (données backend) en priorité
/// - Cela garantit que les quantités non payées sont toujours synchronisées avec le backend
/// - Les métadonnées (orderId, noteId) sont préservées pour la traçabilité
class PaymentValidationService {
  /// Détermine les articles à payer selon la sélection
  static List<Map<String, dynamic>> getItemsToPay({
    required String selectedNoteForPayment,
    required Map<int, int> selectedPartialQuantities,
    required List<Map<String, dynamic>> organizedItemsForPartialPayment,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required List<Map<String, dynamic>> Function() getAllItemsOrganized,
  }) {
    if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isNotEmpty) {
      // Paiement partiel : seulement les articles sélectionnés
      // 🎯 BASTA : On envoie juste l'ID et la quantité, le serveur fait le reste
      return selectedPartialQuantities.entries.map((entry) {
        final itemId = entry.key;
        final quantity = entry.value;
        final item = organizedItemsForPartialPayment.firstWhere(
          (item) => item['id'] == itemId,
          orElse: () => {'id': itemId, 'name': 'Article inconnu', 'price': 0.0}
        );
        
        return {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'quantity': quantity,
          'noteId': 'main', // 🎯 Pour paiement partiel, on force 'main' car c'est une partie de la note principale
        };
      }).toList();
    } else if (selectedNoteForPayment == 'main') {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Fouiller dans les sources pour la note principale
      // 🆕 CORRECTION : Utiliser l'itemId et noteId de chaque source pour éviter les mélanges
      final allItems = getAllItemsOrganized();
      final List<Map<String, dynamic>> itemsToPay = [];
      
      for (final item in allItems) {
        final sources = item['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          // 🆕 CORRECTION : Extraire chaque source avec son ID et noteId originaux
          for (final source in sources) {
            final sourceNoteId = source['noteId'] as String?;
            if (sourceNoteId == 'main' || sourceNoteId == null) {
              final sourceQuantity = source['quantity'] as int? ?? 0;
              if (sourceQuantity > 0) {
                itemsToPay.add({
                  'id': source['itemId'] ?? item['id'], // 🆕 Utiliser l'ID original de la source
                  'name': item['name'],
                  'price': item['price'],
                  'quantity': sourceQuantity,
                  'noteId': 'main', // 🆕 Toujours 'main' pour le paiement de la note principale
                  'orderId': source['orderId'], // 🆕 Préserver orderId pour traçabilité
                });
              }
            }
          }
        } else if (item['noteId'] == 'main' || item['noteId'] == null) {
          // Fallback pour les articles sans sources (ancien format)
          itemsToPay.add({
            'id': item['id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': item['quantity'],
            'noteId': 'main',
          });
        }
      }
      return itemsToPay;
    } else if (selectedNoteForPayment.startsWith('sub_')) {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Fouiller dans les sources pour la sous-note
      // 🆕 CORRECTION : Utiliser l'itemId et noteId de chaque source pour éviter les mélanges
      final allItems = getAllItemsOrganized();
      final List<Map<String, dynamic>> itemsToPay = [];
      
      for (final item in allItems) {
        final sources = item['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          // 🆕 CORRECTION : Extraire chaque source avec son ID et noteId originaux
          for (final source in sources) {
            final sourceNoteId = source['noteId'] as String?;
            if (sourceNoteId == selectedNoteForPayment) {
              final sourceQuantity = source['quantity'] as int? ?? 0;
              if (sourceQuantity > 0) {
                itemsToPay.add({
                  'id': source['itemId'] ?? item['id'], // 🆕 Utiliser l'ID original de la source
                  'name': item['name'],
                  'price': item['price'],
                  'quantity': sourceQuantity,
                  'noteId': selectedNoteForPayment, // 🆕 Utiliser le noteId de la source
                  'orderId': source['orderId'], // 🆕 Préserver orderId pour traçabilité
                });
              }
            }
          }
        } else if (item['noteId'] == selectedNoteForPayment) {
          // Fallback pour les articles sans sources (ancien format)
          itemsToPay.add({
            'id': item['id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': item['quantity'],
            'noteId': selectedNoteForPayment,
          });
        }
      }
      return itemsToPay;
    } else {
      // Paiement complet : utiliser TOUS les articles (main + sous-notes)
      // 🎯 BASTA : On envoie la liste des articles regroupés par ID et noteId
      final allItems = getAllItemsOrganized();
      return allItems.map((item) => {
        'id': item['id'],
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'],
        'noteId': item['noteId'],
      }).toList();
    }
  }

  /// Valide les prérequis avant de traiter le paiement
  static String? validatePaymentPrerequisites({
    required String selectedPaymentMode,
    required String selectedNoteForPayment,
    required Map<int, int> selectedPartialQuantities,
    required bool needsInvoice,
    required String companyName,
    required Object? selectedClientForCredit,
  }) {
    // Validation pour paiement crédit
    if (selectedPaymentMode == 'CREDIT' && selectedClientForCredit == null) {
      return 'CREDIT_DIALOG'; // Signale qu'il faut ouvrir le dialog
    }
    
    // Validation pour paiement partiel
    if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isEmpty) {
      return 'Veuillez sélectionner des articles pour le paiement partiel';
    }
    
    // Validation pour facture
    if (needsInvoice && companyName.isEmpty) {
      return 'Nom de la société requis pour la facture';
    }
    
    return null; // Aucune erreur
  }

  /// Traite le paiement selon le type sélectionné
  static Future<void> processPayment({
    required String selectedNoteForPayment,
    required Map<int, int> selectedPartialQuantities,
    required String tableNumber,
    required String tableId,
    required String selectedPaymentMode,
    required List<Map<String, dynamic>> itemsToPay,
    required List<Map<String, dynamic>> organizedItemsForPartialPayment,
    double? finalAmount, // 🆕 Montant réellement payé (avec remise)
    double? discount, // 🆕 Montant ou pourcentage de remise
    bool? isPercentDiscount, // 🆕 Type de remise
    String? discountClientName, // 🆕 Nom du client pour justifier la remise
    Map<String, double>? splitPayments, // 🆕 DEPRECATED: Utiliser splitPaymentTransactions à la place
    Map<String, int>? splitCreditClients, // 🆕 DEPRECATED: Utiliser splitPaymentTransactions à la place
    List<Map<String, dynamic>>? splitPaymentTransactions, // 🆕 Liste de transactions (nouveau format)
    String? serverName, // 🆕 CORRECTION : Ajouter le serveur pour les détails des remises KPI
    double? scripturalEnteredAmount, // 🆕 Montant réellement saisi pour paiement scriptural simple (CARTE/TPE/CHEQUE)
    int? clientId, // 🆕 ID du client pour paiements CREDIT simples
  }) async {
    if (selectedNoteForPayment == 'all') {
      // Paiement complet : utiliser payMultiOrders pour TOUS les articles
      // Créer une map de tous les articles avec leurs quantités
      final Map<int, int> allItemsQuantities = {};
      for (final item in itemsToPay) {
        final itemId = item['id'] as int;
        final quantity = item['quantity'] as int;
        allItemsQuantities[itemId] = (allItemsQuantities[itemId] ?? 0) + quantity;
      }
      
      await PaymentService.payMultiOrders(
        tableNumber: tableNumber,
        paymentMode: selectedPaymentMode == 'SPLIT' ? null : selectedPaymentMode, // 🆕 null si paiement divisé
        selectedItems: allItemsQuantities,
        organizedItems: organizedItemsForPartialPayment,
        finalAmount: finalAmount, // 🆕 Passer le montant avec remise
        discount: discount, // 🆕 Passer la remise
        isPercentDiscount: isPercentDiscount, // 🆕 Passer le type de remise
        discountClientName: discountClientName, // 🆕 Passer le nom du client
        splitPayments: splitPayments, // 🆕 DEPRECATED
        splitCreditClients: splitCreditClients, // 🆕 DEPRECATED
        splitPaymentTransactions: splitPaymentTransactions, // 🆕 Liste de transactions
        serverName: serverName, // 🆕 CORRECTION : Transmettre le serveur
        scripturalEnteredAmount: scripturalEnteredAmount, // 🆕 Montant réellement saisi pour paiement scriptural simple
        clientId: clientId, // 🆕 Passer l'ID du client pour paiements CREDIT simples
      );
      
      // Fermer la table après paiement complet
      await PaymentService.closeTableAfterPayment(
        tableId: tableId,
        tableNumber: tableNumber,
      );
    } else if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isNotEmpty) {
      await PaymentService.payMultiOrders(
        tableNumber: tableNumber,
        paymentMode: selectedPaymentMode == 'SPLIT' ? null : selectedPaymentMode, // 🆕 null si paiement divisé
        selectedItems: selectedPartialQuantities,
        organizedItems: organizedItemsForPartialPayment,
        finalAmount: finalAmount, // 🆕 Passer le montant avec remise
        discount: discount, // 🆕 Passer la remise
        isPercentDiscount: isPercentDiscount, // 🆕 Passer le type de remise
        discountClientName: discountClientName, // 🆕 Passer le nom du client
        splitPayments: splitPayments, // 🆕 DEPRECATED
        splitCreditClients: splitCreditClients, // 🆕 DEPRECATED
        splitPaymentTransactions: splitPaymentTransactions, // 🆕 Liste de transactions
        serverName: serverName, // 🆕 CORRECTION : Transmettre le serveur
        clientId: clientId, // 🆕 Passer l'ID du client pour paiements CREDIT simples
      );
    } else if (selectedNoteForPayment == 'main') {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser la même logique que pour 'all'
      // itemsToPay contient déjà les unpaidQuantity correctes avec orderId/noteId depuis getAllItemsOrganized()
      // Filtrer organizedItems pour ne garder que les articles de la note principale
      final mainNoteItemsOnly = organizedItemsForPartialPayment.where((item) {
        final noteId = item['noteId'] as String?;
        return noteId == 'main' || noteId == null; // Garder seulement les articles de la note principale
      }).toList();
      
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Sommer simplement les quantités comme pour 'all'
      // car itemsToPay contient déjà les unpaidQuantity correctes depuis getAllItemsOrganized()
      // payMultiOrders va distribuer correctement les quantités entre les instances disponibles
      final Map<int, int> allItemsQuantities = {};
      for (final item in itemsToPay) {
        final itemId = item['id'] as int;
        final quantity = item['quantity'] as int;
        allItemsQuantities[itemId] = (allItemsQuantities[itemId] ?? 0) + quantity;
      }
      
      await PaymentService.payMultiOrders(
        tableNumber: tableNumber,
        paymentMode: selectedPaymentMode == 'SPLIT' ? null : selectedPaymentMode, // 🆕 null si paiement divisé
        selectedItems: allItemsQuantities,
        organizedItems: mainNoteItemsOnly, // 🆕 Utiliser seulement les articles de la note principale
        finalAmount: finalAmount, // 🆕 Passer le montant avec remise
        discount: discount, // 🆕 Passer la remise
        isPercentDiscount: isPercentDiscount, // 🆕 Passer le type de remise
        discountClientName: discountClientName, // 🆕 Passer le nom du client
        splitPayments: splitPayments, // 🆕 DEPRECATED
        splitCreditClients: splitCreditClients, // 🆕 DEPRECATED
        splitPaymentTransactions: splitPaymentTransactions, // 🆕 Liste de transactions
        serverName: serverName, // 🆕 CORRECTION : Transmettre le serveur
        clientId: clientId, // 🆕 Passer l'ID du client pour paiements CREDIT simples
      );
    } else if (selectedNoteForPayment.startsWith('sub_')) {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser la même logique que pour 'all' et 'main'
      // Cela permet de payer une sous-note même si elle est répartie sur plusieurs commandes
      final Map<int, int> allItemsQuantities = {};
      for (final item in itemsToPay) {
        final itemId = item['id'] as int;
        final quantity = item['quantity'] as int;
        allItemsQuantities[itemId] = (allItemsQuantities[itemId] ?? 0) + quantity;
      }
      
      await PaymentService.payMultiOrders(
        tableNumber: tableNumber,
        paymentMode: selectedPaymentMode == 'SPLIT' ? null : selectedPaymentMode,
        selectedItems: allItemsQuantities,
        organizedItems: itemsToPay, // itemsToPay contient déjà tous les articles avec leurs orderId/noteId
        finalAmount: finalAmount,
        discount: discount,
        isPercentDiscount: isPercentDiscount,
        discountClientName: discountClientName,
        splitPayments: splitPayments, // 🆕 DEPRECATED
        splitCreditClients: splitCreditClients, // 🆕 DEPRECATED
        splitPaymentTransactions: splitPaymentTransactions, // 🆕 Liste de transactions
        serverName: serverName, // 🆕 CORRECTION : Transmettre le serveur
        clientId: clientId, // 🆕 Passer l'ID du client pour paiements CREDIT simples
      );
    }
  }
}

