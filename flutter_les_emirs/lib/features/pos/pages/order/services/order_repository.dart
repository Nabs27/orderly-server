import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../../../core/api_client.dart';
import '../../../models/order_note.dart';

class OrderRepository {
  // Charger le menu
  static Future<Map<String, dynamic>?> loadMenu() async {
    try {
      final res = await ApiClient.dio.get('/menu/les-emirs', queryParameters: {'lng': 'fr'});
      return res.data as Map<String, dynamic>;
    } catch (e) {
      print('[POS] Erreur chargement menu: $e');
      return null;
    }
  }

  // Charger les commandes existantes d'une table
  static Future<Map<String, dynamic>?> loadExistingOrder(String tableNumber) async {
    try {
      // 🆕 Charger le menu en parallèle pour obtenir les types des articles
      final menuFuture = loadMenu();
      
      final res = await ApiClient.dio.get('/orders', queryParameters: {'table': tableNumber});
      final orders = (res.data as List).cast<Map<String, dynamic>>();
      
      if (orders.isEmpty) {
        print('[POS] Aucune commande trouvée pour la table $tableNumber');
        return null;
      }
      
      print('[POS] ${orders.length} commandes trouvées pour la table $tableNumber');
      
      // 🆕 Attendre le menu pour le tri
      final menu = await menuFuture;
      
      int tableCovers = 1;
      for (final order in orders) {
        final mainNoteData = order['mainNote'] as Map<String, dynamic>?;
        if (mainNoteData != null && mainNoteData['covers'] != null) {
          tableCovers = (mainNoteData['covers'] as num?)?.toInt() ?? tableCovers;
          break;
        }
        final orderCovers = (order['covers'] as num?);
        if (orderCovers != null) {
          tableCovers = orderCovers.toInt();
          break;
        }
      }
      
      // 🔧 CORRECTION : Charger TOUTES les commandes ET agréger les articles identiques
      final Map<String, OrderNoteItem> aggregatedMainItems = {};
      final allSubNotes = <String, OrderNote>{};
      
      // Parcourir toutes les commandes pour récupérer et agréger tous les articles
      for (final order in orders) {
        // Charger la structure avec notes si elle existe
        if (order.containsKey('mainNote') && order['mainNote'] != null) {
          final mainNoteData = order['mainNote'] as Map<String, dynamic>;
          final mainItems = (mainNoteData['items'] as List?) ?? [];
          
          // 🆕 Agréger les articles identiques de la note principale (seulement les non payés)
          for (final itemData in mainItems) {
            final item = OrderNoteItem.fromJson(itemData as Map<String, dynamic>);
            
            // 🆕 Calculer la quantité non payée
            final totalQuantity = item.quantity;
            final paidQuantity = (itemData['paidQuantity'] as num?)?.toInt() ?? 0;
            final unpaidQuantity = totalQuantity - paidQuantity;
            
            // 🆕 Ne garder que les articles avec quantité non payée > 0
            if (unpaidQuantity > 0) {
              // 🆕 Utiliser la quantité non payée (avec métadonnées commande/note)
              final itemWithUnpaidQuantity = item.copyWith(
                quantity: unpaidQuantity,
                isSent: true,
                sourceOrderId: order['id'] as int?,
                sourceNoteId: 'main',
              );
              // 🆕 CORRECTION: Regrouper par (id, name) seulement, pas par (orderId, id, name)
              // Cela permet de regrouper les articles identiques de plusieurs commandes
              final itemKey = 'main-${item.id}-${item.name}';
              
              if (aggregatedMainItems.containsKey(itemKey)) {
                // Article déjà présent : additionner les quantités
                aggregatedMainItems[itemKey] = aggregatedMainItems[itemKey]!.copyWith(
                  quantity: aggregatedMainItems[itemKey]!.quantity + unpaidQuantity,
                  isSent: true,
                );
              } else {
                aggregatedMainItems[itemKey] = itemWithUnpaidQuantity;
              }
            }
          }
          
          // 🆕 Ajouter les sous-notes avec agrégation des articles identiques (seulement les non payées)
          // 🆕 CORRECTION : Fusionner les articles de TOUTES les commandes pour la même sous-note
          final subNotesData = (order['subNotes'] as List?) ?? [];
          for (final subNoteData in subNotesData) {
            // 🆕 Ignorer les sous-notes complètement payées
            final notePaid = subNoteData['paid'] == true;
            if (notePaid) {
              print('[POS] Sous-note ${subNoteData['id']} complètement payée - ignorée');
              continue;
            }
            
            final subNote = OrderNote.fromJson(subNoteData as Map<String, dynamic>);
            
            // 🆕 CORRECTION : Récupérer ou créer la map d'articles agrégés pour cette sous-note
            // Si la sous-note existe déjà dans allSubNotes, récupérer ses articles existants
            final existingSubNote = allSubNotes[subNote.id];
            final Map<String, OrderNoteItem> aggregatedSubItems = {};
            
            // Si la sous-note existe déjà, initialiser avec ses articles existants
            if (existingSubNote != null) {
              for (final existingItem in existingSubNote.items) {
                final itemKey = '${subNote.id}-${existingItem.id}-${existingItem.name}';
                aggregatedSubItems[itemKey] = existingItem;
              }
            }
            
            // Ajouter les articles de cette commande
            final subNoteItemsData = (subNoteData['items'] as List?) ?? [];
            for (final itemData in subNoteItemsData) {
              final item = OrderNoteItem.fromJson(itemData as Map<String, dynamic>);
              
              // 🆕 Calculer la quantité non payée
              final totalQuantity = item.quantity;
              final paidQuantity = (itemData['paidQuantity'] as num?)?.toInt() ?? 0;
              final unpaidQuantity = totalQuantity - paidQuantity;
              
              // 🆕 Ne garder que les articles avec quantité non payée > 0
              if (unpaidQuantity > 0) {
                final itemWithUnpaidQuantity = item.copyWith(
                  quantity: unpaidQuantity,
                  isSent: true,
                  sourceOrderId: order['id'] as int?,
                  sourceNoteId: subNote.id,
                );
                // 🆕 CORRECTION: Regrouper par (id, name) seulement pour les sous-notes aussi
                final itemKey = '${subNote.id}-${item.id}-${item.name}';
                if (aggregatedSubItems.containsKey(itemKey)) {
                  // Article déjà présent : additionner les quantités
                  aggregatedSubItems[itemKey] = aggregatedSubItems[itemKey]!.copyWith(
                    quantity: aggregatedSubItems[itemKey]!.quantity + unpaidQuantity,
                    isSent: true,
                  );
                } else {
                  aggregatedSubItems[itemKey] = itemWithUnpaidQuantity;
                }
              }
            }
            
            // 🆕 Afficher la sous-note si :
            // 1. Elle n'est pas payée (paid: false)
            // 2. ET (elle a des articles non payés OU elle est vide - car elle vient d'être créée)
            // On affiche toujours les sous-notes non payées, même si elles sont vides
            final hasUnpaidItems = aggregatedSubItems.isNotEmpty;
            final isEmpty = subNoteItemsData.isEmpty && existingSubNote == null;
            
            if (hasUnpaidItems || isEmpty) {
              final itemsList = aggregatedSubItems.values.toList();
              final calculatedTotal = itemsList.fold<double>(
                0.0,
                (sum, item) => sum + ((item.price ?? 0.0) * (item.quantity ?? 0)),
              );
              final aggregatedSubNote = subNote.copyWith(
                items: itemsList,
                total: calculatedTotal,
                sourceOrderId: order['id'] as int?, // 🆕 Garder le dernier orderId pour référence
              );
              
              allSubNotes[aggregatedSubNote.id] = aggregatedSubNote;
              print('[POS] Sous-note ${subNote.id} (${subNote.name}) fusionnée - articles non payés: ${aggregatedSubItems.length}, total: $calculatedTotal');
            } else {
              print('[POS] Sous-note ${subNote.id} (${subNote.name}) ignorée - tous les articles sont payés et elle n\'est pas vide');
            }
          }
        } else {
          // Ancienne structure (compatibilité) - ajouter à la note principale
          // 🆕 Filtrer les articles payés aussi pour l'ancienne structure
          final items = (order['items'] as List?) ?? [];
          for (final itemData in items) {
            final item = OrderNoteItem.fromJson(itemData as Map<String, dynamic>);
            
            // 🆕 Calculer la quantité non payée
            final totalQuantity = item.quantity;
            final paidQuantity = (itemData['paidQuantity'] as num?)?.toInt() ?? 0;
            final unpaidQuantity = totalQuantity - paidQuantity;
            
            // 🆕 Ne garder que les articles avec quantité non payée > 0
            if (unpaidQuantity > 0) {
              final itemWithUnpaidQuantity = item.copyWith(
                quantity: unpaidQuantity,
                isSent: true,
                sourceOrderId: order['id'] as int?,
                sourceNoteId: 'main',
              );
              // 🆕 CORRECTION: Regrouper par (id, name) seulement (ancienne structure)
              final itemKey = 'main-${item.id}-${item.name}';
              
              if (aggregatedMainItems.containsKey(itemKey)) {
                // Article déjà présent : additionner les quantités
                aggregatedMainItems[itemKey] = aggregatedMainItems[itemKey]!.copyWith(
                  quantity: aggregatedMainItems[itemKey]!.quantity + unpaidQuantity,
                  isSent: true,
                );
              } else {
                aggregatedMainItems[itemKey] = itemWithUnpaidQuantity;
              }
            }
          }
        }
      }
      
      // 🆕 Trier les articles par catégorie (boissons → entrées → plats → desserts)
      final allMainItems = _sortItemsByCategory(aggregatedMainItems.values.toList(), menu);
      final activeOrderId = orders.isNotEmpty ? orders.first['id'] as int? : null;
      
      // 🆕 Trier aussi les articles des sous-notes par catégorie
      final sortedSubNotes = allSubNotes.values.map((note) {
        final sortedItems = _sortItemsByCategory(note.items, menu);
        final calculatedTotal = sortedItems.fold<double>(
          0.0,
          (sum, item) => sum + ((item.price ?? 0.0) * (item.quantity ?? 0)),
        );
        print('[POS] Sous-note ${note.id} (${note.name}): ${sortedItems.length} articles, total calculé: $calculatedTotal');
        return note.copyWith(
          items: sortedItems,
          total: calculatedTotal,
        );
      }).toList();
      
      return {
        'mainItems': allMainItems,
        'subNotes': sortedSubNotes,
        'activeOrderId': activeOrderId,
        'covers': tableCovers,
        // 🆕 Retourner aussi les commandes brutes pour la vue chronologique
        'rawOrders': orders,
      };
    } catch (e) {
      print('[POS] Erreur chargement commandes: $e');
      return null;
    }
  }

  /// 🆕 Trier les articles par catégorie selon l'ordre du menu
  /// Utilise le type des articles (depuis le menu) pour un tri précis
  static List<OrderNoteItem> _sortItemsByCategory(List<OrderNoteItem> items, Map<String, dynamic>? menu) {
    if (items.isEmpty || menu == null) return items;
    
    // Map itemId -> type depuis le menu
    final itemTypeMap = <int, String>{};
    final categories = (menu['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final cat in categories) {
      for (final item in (cat['items'] as List?)?.cast<Map<String, dynamic>>() ?? []) {
        final id = (item['id'] as num?)?.toInt();
        final type = item['type'] as String?;
        if (id != null && type != null) itemTypeMap[id] = type;
      }
    }
    
    // Ordre des types (selon l'ordre du menu)
    const typeOrder = {
      'boisson froide': 10,
      'boisson chaude': 11,
      'apéritif': 20,
      'whisky': 21,
      'bière': 22,
      'cocktail': 23,
      'shot': 24,
      'vin blanc': 25,
      'vin rosé': 26,
      'vin rouge': 27,
      'vin français': 28,
      'champagne': 30,
      'digestif': 31,
      'entrée froide': 40,
      'entrée chaude': 41,
      'plat tunisien': 50,
      'pâtes': 51,
      'volaille': 52,
      'viande': 53,
      'poisson': 54,
      'dessert': 60,
    };
    
    final sorted = List<OrderNoteItem>.from(items);
    sorted.sort((a, b) {
      final typeA = itemTypeMap[a.id]?.toLowerCase();
      final typeB = itemTypeMap[b.id]?.toLowerCase();
      final orderA = typeOrder[typeA] ?? (typeA?.startsWith('vin ') == true ? 29 : 999);
      final orderB = typeOrder[typeB] ?? (typeB?.startsWith('vin ') == true ? 29 : 999);
      
      return orderA != orderB 
          ? orderA.compareTo(orderB)
          : a.name.compareTo(b.name);
    });
    
    return sorted;
  }

  // Sauvegarder l'orderId dans SharedPreferences
  static Future<void> saveOrderIdToTable({
    required int orderId,
    required String tableId,
    required String tableNumber,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
    required double totalAmount,
    required int covers,
    required List<Map<String, dynamic>> ticketItems,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverNames = ['ALI', 'MOHAMED', 'FATIMA', 'ADMIN'];
      
      final orderData = {
        'orderId': orderId,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'mainNote': mainNote.toJson(),
        'subNotes': subNotes.map((n) => n.toJson()).toList(),
        'total': totalAmount,
        'covers': covers,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('pos_order_$orderId', jsonEncode(orderData));
      
      for (final serverName in serverNames) {
        final tablesJson = prefs.getString('pos_tables_$serverName');
        if (tablesJson != null) {
          final List<dynamic> decoded = jsonDecode(tablesJson);
          bool updated = false;
          
          final tables = decoded.map((t) {
            final table = Map<String, dynamic>.from(t);
            
            if (table['id'] == tableId) {
              table['orderId'] = orderId;
              table['orderItems'] = ticketItems;
              table['orderTotal'] = totalAmount;
              table['lastOrderAt'] = DateTime.now().toIso8601String(); // 🆕 Mettre à jour le timestamp de la dernière commande
              updated = true;
            }
            
            return table;
          }).toList();
          
          if (updated) {
            await prefs.setString('pos_tables_$serverName', jsonEncode(tables));
            print('[POS] OrderId $orderId et détails sauvegardés pour table $tableId');
            break;
          }
        }
      }
    } catch (e) {
      print('[POS] Erreur sauvegarde orderId: $e');
    }
  }
}

