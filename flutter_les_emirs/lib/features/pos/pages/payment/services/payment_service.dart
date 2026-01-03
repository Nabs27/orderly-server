import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../../core/api_client.dart';

class PaymentService {
  // Enregistrer un paiement individuel (pour détails restaurateur)
  static Future<void> recordIndividualPayment({
    required String tableNumber,
    required String paymentType,
    required String paymentMode,
    required double amount,
    required List<Map<String, dynamic>> items,
    required double discount,
    required bool isPercentDiscount,
    required int covers,
    required bool needsInvoice,
  }) async {
    try {
      final paymentRecord = {
        'table': tableNumber,
        'paymentType': paymentType,
        'paymentMode': paymentMode,
        'amount': amount,
        'items': items,
        'discount': discount,
        'isPercentDiscount': isPercentDiscount,
        'covers': covers,
        'timestamp': DateTime.now().toIso8601String(),
        'needsInvoice': needsInvoice,
      };
      
      final prefs = await SharedPreferences.getInstance();
      final paymentKey = 'payment_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(paymentKey, jsonEncode(paymentRecord));
      
      print('[PAYMENT] Paiement individuel enregistré: $paymentKey');
    } catch (e) {
      print('Erreur lors de l\'enregistrement du paiement individuel: $e');
    }
  }

  // Supprimer les articles d'une note spécifique
  static Future<void> removeNoteItemsFromTable({
    required String tableNumber,
    required String noteId,
    required List<Map<String, dynamic>> itemsToRemove,
    String? paymentMode, // 🆕 Nullable pour paiement divisé
    double? finalAmount, // 🆕 Montant réellement payé (avec remise)
    double? discount, // 🆕 Montant ou pourcentage de remise
    bool? isPercentDiscount, // 🆕 Type de remise
    String? discountClientName, // 🆕 Nom du client pour justifier la remise
    Map<String, double>? splitPayments, // 🆕 Paiements divisés (mode -> montant)
    Map<String, int>? splitCreditClients, // 🆕 Clients CREDIT pour paiement divisé (mode -> clientId)
  }) async {
    try {
      print('[PAYMENT] Suppression des articles de la note: $noteId');
      if (discount != null && discount > 0) {
        print('[PAYMENT] Remise: $discount ${isPercentDiscount == true ? '%' : 'TND'}, Montant final: $finalAmount TND');
      }
      final ordersResponse = await ApiClient.dio.get('/orders?table=$tableNumber');
      final orders = ordersResponse.data as List;
      if (orders.isEmpty) {
        throw Exception('Aucune commande trouvée pour la table $tableNumber');
      }

      // Cas simple: sous-note spécifique → trouver la commande et supprimer
      if (noteId != 'main') {
        int? orderId;
        // Recherche directe de la sous-note dans toutes les commandes
        for (final order in orders) {
          final subNotes = order['subNotes'] as List? ?? [];
          if (subNotes.any((note) => note['id'] == noteId)) {
            orderId = order['id'] as int;
            break;
          }
        }
        if (orderId == null) {
          print('[PAYMENT] Aucune commande trouvée contenant la note: $noteId');
          return;
        }
        // Vérifier existence note
        final order = orders.firstWhere((o) => o['id'] == orderId);
        final subNotes = order['subNotes'] as List? ?? [];
        final noteExists = subNotes.any((note) => note['id'] == noteId && (note['items'] as List).isNotEmpty);
        if (!noteExists) {
          print('[PAYMENT] Note $noteId n\'existe plus ou est vide, suppression ignorée');
          return;
        }
        // 🆕 Préparer les données de paiement (simple ou divisé)
        final paymentData = <String, dynamic>{
          'items': itemsToRemove.map((item) => {
            'id': item['id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': item['quantity'],
          }).toList(),
          'finalAmount': finalAmount,
          'discount': discount,
          'isPercentDiscount': isPercentDiscount,
          'discountClientName': discountClientName,
        };
        
        // 🆕 Ajouter paymentMode ou splitPayments selon le cas
        if (splitPayments != null && splitPayments.isNotEmpty) {
          // Paiement divisé : convertir en format backend
          paymentData['splitPayments'] = splitPayments.entries.map((entry) {
            return {
              'mode': entry.key,
              'amount': entry.value,
              'clientId': splitCreditClients?[entry.key],
            };
          }).toList();
          print('[PAYMENT] 🆕 Paiement divisé envoyé: ${paymentData['splitPayments']}');
        } else {
          // Paiement simple
          paymentData['paymentMode'] = paymentMode ?? 'ESPECE';
        }
        
        await ApiClient.dio.delete('/api/pos/orders/$orderId/notes/$noteId/items', data: paymentData);
        print('[PAYMENT] Articles supprimés de la note $noteId');
        return;
      }

      // Cas complexe: note principale → répartir sur TOUTES les commandes de la table
      // Construire un pool des quantités à retirer par itemId
      final Map<int, Map<String, dynamic>> remainingByItemId = {};
      for (final it in itemsToRemove) {
        final id = it['id'] as int;
        final qty = (it['quantity'] as num).toInt();
        remainingByItemId[id] = {
          'id': id,
          'name': it['name'],
          'price': (it['price'] as num).toDouble(),
          'remaining': qty,
        };
      }

      // Parcourir les commandes et préparer les suppressions par commande
      final List<Map<String, dynamic>> batchedDeletes = []; // {orderId, items, subtotal}
      for (final order in orders) {
        final main = order['mainNote'] as Map<String, dynamic>?;
        if (main == null) continue;
        final mainItems = main['items'] as List? ?? [];
        final List<Map<String, dynamic>> itemsForThisOrder = [];
        for (final item in mainItems) {
          final id = item['id'] as int?;
          if (id == null) continue;
          if (!remainingByItemId.containsKey(id)) continue;
          final totalQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final paidQuantity = (item['paidQuantity'] as num?)?.toInt() ?? 0;
          final unpaidQuantity = totalQuantity - paidQuantity;
          if (unpaidQuantity <= 0) continue;
          final rem = (remainingByItemId[id]!['remaining'] as int);
          if (rem <= 0) continue;
          final take = rem < unpaidQuantity ? rem : unpaidQuantity;
          if (take > 0) {
            itemsForThisOrder.add({
              'id': id,
              'name': item['name'],
              'price': (item['price'] as num).toDouble(),
              'quantity': take,
            });
            remainingByItemId[id]!['remaining'] = rem - take;
          }
        }
        if (itemsForThisOrder.isNotEmpty) {
          final subtotal = itemsForThisOrder.fold<double>(0.0, (s, it) => s + ((it['price'] as double) * (it['quantity'] as int)));
          batchedDeletes.add({
            'orderId': order['id'] as int,
            'items': itemsForThisOrder,
            'subtotal': subtotal,
          });
        }
      }

      if (batchedDeletes.isEmpty) {
        print('[PAYMENT] Rien à supprimer pour note main (quantités déjà soldées)');
        return;
      }

      final totalSubtotal = batchedDeletes.fold<double>(0.0, (s, b) => s + (b['subtotal'] as double));

      // Exécuter les suppressions par commande avec allocation proportionnelle du montant/remise
      for (final batch in batchedDeletes) {
        final int orderId = batch['orderId'] as int;
        final List<Map<String, dynamic>> items = (batch['items'] as List).cast<Map<String, dynamic>>();
        double? allocFinal;
        double? allocDiscount;
        if ((finalAmount ?? 0) > 0 && totalSubtotal > 0) {
          final proportion = (batch['subtotal'] as double) / totalSubtotal;
          allocFinal = (finalAmount! * proportion);
        } else {
          allocFinal = finalAmount;
        }
        if ((discount ?? 0) > 0 && (isPercentDiscount != true)) {
          // Remise fixe: répartir
          if (totalSubtotal > 0) {
            final proportion = (batch['subtotal'] as double) / totalSubtotal;
            allocDiscount = (discount! * proportion);
          } else {
            allocDiscount = discount;
          }
        } else {
          // Remise pourcentage: identique pour chaque appel (le serveur calcule)
          allocDiscount = discount;
        }

        // 🆕 Préparer les données de paiement (simple ou divisé)
        final paymentDataBatch = <String, dynamic>{
          'items': items.map((it) => {
            'id': it['id'],
            'name': it['name'],
            'price': it['price'],
            'quantity': it['quantity'],
          }).toList(),
          'finalAmount': allocFinal,
          'discount': allocDiscount,
          'isPercentDiscount': isPercentDiscount,
          'discountClientName': discountClientName,
        };
        
        // 🆕 Ajouter paymentMode ou splitPayments selon le cas
        if (splitPayments != null && splitPayments.isNotEmpty) {
          // Paiement divisé : convertir en format backend
          paymentDataBatch['splitPayments'] = splitPayments.entries.map((entry) => {
            'mode': entry.key,
            'amount': entry.value,
            'clientId': splitCreditClients?[entry.key],
          }).toList();
          print('[PAYMENT] 🆕 Paiement divisé envoyé (batch): ${paymentDataBatch['splitPayments']}');
        } else {
          // Paiement simple
          paymentDataBatch['paymentMode'] = paymentMode ?? 'ESPECE';
        }
        
        await ApiClient.dio.delete('/api/pos/orders/$orderId/notes/main/items', data: paymentDataBatch);
        print('[PAYMENT] Articles supprimés de la note main (commande $orderId)');
      }
    } catch (e) {
      print('Erreur lors de la suppression des articles de la note: $e');
      if (e.toString().contains('Note introuvable') || e.toString().contains('404')) {
        print('[PAYMENT] Note déjà supprimée, ignoré');
        return;
      }
      throw e;
    }
  }

  // Paiement multi-commandes
  static Future<void> payMultiOrders({
    required String tableNumber,
    String? paymentMode, // 🆕 Nullable pour paiement divisé
    required Map<int, int> selectedItems,
    required List<Map<String, dynamic>> organizedItems,
    double? finalAmount, // 🆕 Montant réellement payé (avec remise)
    double? discount, // 🆕 Montant ou pourcentage de remise
    bool? isPercentDiscount, // 🆕 Type de remise
    String? discountClientName, // 🆕 Nom du client pour justifier la remise
    Map<String, double>? splitPayments, // 🆕 DEPRECATED: Utiliser splitPaymentTransactions à la place
    Map<String, int>? splitCreditClients, // 🆕 DEPRECATED: Utiliser splitPaymentTransactions à la place
    List<Map<String, dynamic>>? splitPaymentTransactions, // 🆕 Liste de transactions (nouveau format)
    String? serverName, // 🆕 CORRECTION : Ajouter le serveur pour les détails des remises KPI
    double? scripturalEnteredAmount, // 🆕 Montant réellement saisi pour paiement scriptural simple (CARTE/TPE/CHEQUE)
  }) async {
    try {
      print('[PAYMENT-BASTA] Envoi du sac d\'articles pour la table $tableNumber');
      
      // On prépare juste la liste des articles à payer sans chercher d'orderId
      final List<Map<String, dynamic>> itemsToSend = [];
      selectedItems.forEach((itemId, quantity) {
        final item = organizedItems.firstWhere((it) => it['id'] == itemId);
        itemsToSend.add({
          'id': itemId,
          'name': item['name'],
          'price': item['price'],
          'quantity': quantity,
          'noteId': item['noteId'], // Utile pour filtrer Main/Sub sur le serveur
        });
      });

      final paymentData = <String, dynamic>{
        'table': tableNumber,
        'items': itemsToSend, // Le sac est plat, le serveur fera le tri
        'finalAmount': finalAmount,
        'discount': discount,
        'isPercentDiscount': isPercentDiscount,
        'discountClientName': discountClientName,
        'server': serverName, // 🆕 CORRECTION : Transmettre le serveur au backend
      };
      
      // 🆕 Ajouter paymentMode ou splitPayments selon le cas
      if (splitPaymentTransactions != null && splitPaymentTransactions.isNotEmpty) {
        // Paiement divisé : utiliser le nouveau format
        paymentData['splitPayments'] = splitPaymentTransactions;
        print('[PAYMENT] 🆕 Paiement divisé envoyé: ${paymentData['splitPayments']}');
      } else if (splitPayments != null && splitPayments.isNotEmpty) {
        // 🆕 DEPRECATED: Ancien format pour compatibilité
        paymentData['splitPayments'] = splitPayments.entries.map((entry) {
          return {
            'mode': entry.key,
            'amount': entry.value,
            'clientId': splitCreditClients?[entry.key],
          };
        }).toList();
        print('[PAYMENT] 🆕 Paiement divisé envoyé (ancien format): ${paymentData['splitPayments']}');
      } else {
        // Paiement simple
        paymentData['paymentMode'] = paymentMode ?? 'ESPECE';
        if (paymentMode == 'CARTE' || paymentMode == 'CHEQUE' || paymentMode == 'TPE') {
          paymentData['enteredAmount'] = scripturalEnteredAmount; // 🆕 Envoyer le montant réel
        }
      }
      
      final response = await ApiClient.dio.post(
        '/api/pos/pay-multi-orders',
        data: paymentData,
      );
      
      print('[PAYMENT-BASTA] ✅ Succès: ${response.data['totalPaid']} TND');
    } catch (e) {
      print('[PAYMENT-BASTA] ❌ Erreur: $e');
      throw e;
    }
  }

  // Vider la consommation de table
  static Future<void> clearTableConsumption({required String tableNumber}) async {
    try {
      print('[CREDIT] Archivage de la consommation pour table $tableNumber');
      await ApiClient.dio.post(
        '/api/admin/clear-table-consumption',
        data: {'table': tableNumber},
        options: Options(headers: {'x-admin-token': 'admin123'}),
      );
      print('[CREDIT] Consommation de table $tableNumber archivée');
    } catch (e) {
      print('[CREDIT] Erreur lors du vidage de la consommation: $e');
    }
  }

  // Fermer la table après paiement
  static Future<void> closeTableAfterPayment({
    required String tableId,
    required String tableNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pos_table_to_close_$tableId', tableId);
      
      final keys = prefs.getKeys().where((k) => k.startsWith('pos_order_')).toList();
      for (final key in keys) {
        final orderJson = prefs.getString(key);
        if (orderJson != null) {
          try {
            final order = jsonDecode(orderJson);
            if (order['tableId'] == tableId) {
              await prefs.remove(key);
              print('[PAYMENT] Commande ${order['orderId']} nettoyée');
            }
          } catch (e) {
            print('[PAYMENT] Erreur nettoyage commande: $e');
          }
        }
      }
      
      print('[PAYMENT] Table $tableNumber marquée pour fermeture');
    } catch (e) {
      print('Erreur lors de la fermeture de la table: $e');
    }
  }

  // Générer facture PDF
  static Future<String?> generateInvoicePDF({
    required String tableNumber,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String taxNumber,
    required List<Map<String, dynamic>> items,
    required double total,
    required double amountPerPerson,
    required int covers,
    required String paymentMode,
  }) async {
    try {
      final invoiceData = {
        'billId': tableNumber,
        'company': {
          'name': companyName,
          'address': companyAddress,
          'phone': companyPhone,
          'email': companyEmail,
          'taxNumber': taxNumber,
        },
        'items': items,
        'total': total,
        'amountPerPerson': amountPerPerson,
        'covers': covers,
        'paymentMode': paymentMode,
        'date': DateTime.now().toIso8601String(),
      };
      
      final response = await ApiClient.dio.post('/api/admin/generate-invoice', data: invoiceData);
      
      final pdfUrl = response.data['invoice']?['pdfUrl'] as String?;
      
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        print('[POS] Facture PDF générée: $pdfUrl');
        return pdfUrl;
      } else {
        print('Erreur: L\'API n\'a pas retourné de pdfUrl.');
        throw Exception('URL de facture PDF manquante dans la réponse API.');
      }
    } catch (e) {
      print('Erreur génération facture: $e');
      return null;
    }
  }

  // Traiter le paiement crédit client
  static Future<void> processCreditPayment({
    required String clientId,
    required String tableNumber,
    required double amount,
    required String description,
    required Set<int> paidOrderIds,
    required List<Map<String, dynamic>> ticketItems,
    required String serverName,
  }) async {
    try {
      final debitTransaction = {
        'type': 'DEBIT',
        'amount': amount,
        'description': description,
        'orderIds': paidOrderIds.toList(),
        'server': serverName,
        'ticket': {
          'table': tableNumber,
          'date': DateTime.now().toIso8601String(),
          'items': ticketItems,
          'total': amount,
          'server': serverName,
        },
      };

      await ApiClient.dio.post(
        '/api/credit/clients/$clientId/transactions',
        data: debitTransaction,
      );
      
      print('[CREDIT] Transaction crédit créée pour client $clientId');
    } catch (e) {
      print('[CREDIT] Erreur paiement crédit: $e');
      throw e;
    }
  }
}

