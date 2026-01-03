import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../../core/api_client.dart';
import '../../../models/order_note.dart';


/// Service pour gérer les transferts d'articles et de tables
class TransferService {
  /// Exécuter le transfert vers une note
  static Future<bool> executeTransferToNote({
    required String targetNoteId,
    required Map<int, int> selectedItems,
    required String currentTableNumber,
    required int? activeOrderId,
    required String activeNoteId,
    required OrderNote activeNote,
    required List<OrderNote> subNotes,
    required BuildContext context,
    int? targetNoteOrderId,
  }) async {
    try {
      final groups = _groupSelectedItems(
        selectedItems: selectedItems,
        activeNote: activeNote,
        fallbackOrderId: activeOrderId,
        fallbackNoteId: activeNoteId,
      );

      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de déterminer la commande d\'origine des articles sélectionnés'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      int? resolvedTargetOrderId = targetNoteOrderId;
      if (targetNoteId != 'main' && resolvedTargetOrderId == null) {
        final note = subNotes.firstWhere(
          (element) => element.id == targetNoteId,
          orElse: () => OrderNote(
            id: targetNoteId,
            name: targetNoteId,
            covers: 1,
            items: const [],
            total: 0,
            sourceOrderId: null,
          ),
        );
        resolvedTargetOrderId = note.sourceOrderId;
      }

      for (final group in groups.values) {
        final toOrderId = targetNoteId == 'main' ? group.orderId : resolvedTargetOrderId;
        if (toOrderId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commande cible introuvable pour ce transfert'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }

        final transferData = {
          'fromTable': currentTableNumber,
          'fromOrderId': group.orderId,
          'fromNoteId': group.noteId,
          'toTable': currentTableNumber,
          'toOrderId': toOrderId,
          'toNoteId': targetNoteId,
          'items': group.items,
        };

        print('[POS] Envoi transfert vers note: $transferData');
        final response = await ApiClient.dio.post('/api/pos/transfer-items', data: transferData);
        if (response.statusCode != 200) {
          return false;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedItems.length} article(s) transféré(s)'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      print('[POS] Erreur transfert: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du transfert: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  /// Exécuter le transfert vers une table
  static Future<bool> executeTransferToTable({
    required String targetTable,
    required Map<int, int> selectedItems,
    required bool createTable,
    required String currentTableNumber,
    required int? activeOrderId,
    required String activeNoteId,
    required OrderNote activeNote,
    required int covers,
    required String clientName,
    required BuildContext context,
  }) async {
    try {
      final groups = _groupSelectedItems(
        selectedItems: selectedItems,
        activeNote: activeNote,
        fallbackOrderId: activeOrderId,
        fallbackNoteId: activeNoteId,
      );

      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de déterminer la commande d\'origine des articles sélectionnés'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (createTable && groups.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez transférer vers une nouvelle table une commande à la fois.'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      for (final group in groups.values) {
        final transferData = {
          'fromTable': currentTableNumber,
          'fromOrderId': group.orderId,
          'fromNoteId': group.noteId,
          'toTable': targetTable,
          'toOrderId': null,
          'createTable': createTable,
          'tableNumber': createTable ? targetTable : null,
          'covers': createTable ? covers : null,
          'createNote': clientName.isNotEmpty,
          'noteName': clientName.isNotEmpty ? clientName : null,
          'items': group.items,
        };
        
        print('[POS] Envoi transfert vers table: $transferData');
        final response = await ApiClient.dio.post('/api/pos/transfer-items', data: transferData);
        if (response.statusCode != 200) {
          return false;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfert réussi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    } catch (e) {
      print('[POS] Erreur transfert: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du transfert: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  /// Transférer des articles directement (pour nouvelles notes)
  static Future<bool> transferItemsDirectly({
    required String targetNoteId,
    required Map<int, int> selectedItems,
    required String currentTableNumber,
    required int? activeOrderId,
    required String activeNoteId,
    required OrderNote activeNote,
    required BuildContext context,
  }) async {
    try {
      final groups = _groupSelectedItems(
        selectedItems: selectedItems,
        activeNote: activeNote,
        fallbackOrderId: activeOrderId,
        fallbackNoteId: activeNoteId,
      );

      if (groups.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ce type de transfert est limité aux articles d\'une seule commande'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      final group = groups.values.first;
      final transferData = {
        'fromTable': currentTableNumber,
        'fromOrderId': group.orderId,
        'fromNoteId': group.noteId,
        'toTable': currentTableNumber,
        'toOrderId': group.orderId,
        'toNoteId': targetNoteId,
        'items': group.items,
      };

      print('[POS] Transfert direct vers note $targetNoteId: ${group.items.length} articles');
      final response = await ApiClient.dio.post('/api/pos/transfer-items', data: transferData);
      
      return response.statusCode == 200;
    } catch (e) {
      print('[POS] Erreur transfert direct: $e');
      return false;
    }
  }

  /// Exécuter le transfert complet de table
  static Future<bool> executeCompleteTableTransfer({
    required String targetTable,
    required bool createTable,
    required String currentTableNumber,
    required String selectedServer,
    required int covers,
    required BuildContext context,
  }) async {
    try {
      final response = await ApiClient.dio.post('/api/pos/transfer-complete-table', data: {
        'fromTable': currentTableNumber,
        'toTable': targetTable,
        'server': selectedServer,
        'createTable': createTable,
        'covers': covers,
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table $currentTableNumber transférée vers Table $targetTable'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('[POS] Erreur transfert complet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  /// Exécuter le transfert serveur
  static Future<bool> executeServerTransfer({
    required String targetServer,
    required List<String> tablesToTransfer,
    required String currentTableNumber,
    required BuildContext context,
  }) async {
    try {
      for (String tableNumber in tablesToTransfer) {
        final response = await ApiClient.dio.post('/api/pos/transfer-server', data: {
          'table': tableNumber,
          'newServer': targetServer,
        });
        if (response.statusCode != 200) {
          throw Exception('Erreur transfert table $tableNumber');
        }
        print('[TRANSFER-SERVER] Table $tableNumber transférée vers $targetServer');
      }
      
      if (!context.mounted) return false;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tablesToTransfer.length} table(s) transférée(s) vers $targetServer'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      print('[POS] Erreur transfert serveur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  /// Envoyer à la cuisine (créer commande ou ajouter à commande existante)
  static Future<int?> sendToKitchen({
    required String selectedServer,
    required String currentTableNumber,
    required String currentTableId,
    required String activeNoteId,
    required OrderNote activeNote,
    required List<OrderNote> subNotes,
    required Set<int> newlyAddedItems,
    required Map<int, int> newlyAddedQuantities,
    required int? activeOrderId,
    required String notes,
    required BuildContext context,
    required int covers,
  }) async {
    if (selectedServer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un serveur avant de passer commande'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }
    
    if (activeNote.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article dans le ticket')),
      );
      return null;
    }

    try {
      // Envoyer SEULEMENT les nouveaux articles ajoutés lors de cette session
      final newItems = <OrderNoteItem>[];
      
      if (newlyAddedItems.isNotEmpty && newlyAddedQuantities.isNotEmpty) {
        for (final itemId in newlyAddedItems) {
          final item = activeNote.items.firstWhere(
            (it) => it.id == itemId,
            orElse: () => activeNote.items.first,
          );
          final quantity = newlyAddedQuantities[itemId] ?? item.quantity;
          newItems.add(item.copyWith(quantity: quantity));
        }
      } else {
        newItems.addAll(
          activeNote.items
              .where((item) => item.isSent == false)
              .map((item) => item.copyWith(quantity: item.quantity))
        );
      }
      
      if (newItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun article à envoyer')),
        );
        return null;
      }
      
      Response res;
      
      // 🆕 CORRECTION : Créer une NOUVELLE commande pour les sous-notes aussi
      // Au lieu d'ajouter à une commande existante, on crée une nouvelle commande
      // avec le même noteId et noteName, ce qui génère un nouvel orderId
      // Cela permet d'avoir des commandes séparées dans l'affichage chronologique
      if (activeNoteId == 'main') {
        final payload = {
          'table': currentTableNumber,
          'items': newItems.map((it) => {
            'id': it.id,
            'name': it.name,
            'price': it.price,
            'quantity': it.quantity,
          }).toList(),
          'notes': notes,
          'server': selectedServer,
          'covers': covers,
          'noteId': 'main',
          'noteName': 'Note Principale',
        };
        res = await ApiClient.dio.post('/orders', data: payload);
      } else {
        // 🆕 Créer une nouvelle commande pour la sous-note (comme pour la note principale)
        final payload = {
          'table': currentTableNumber,
          'items': newItems.map((it) => {
            'id': it.id,
            'name': it.name,
            'price': it.price,
            'quantity': it.quantity,
          }).toList(),
          'notes': notes,
          'server': selectedServer,
          'covers': activeNote.covers,
          'noteId': activeNoteId, // 🆕 Utiliser le noteId de la sous-note
          'noteName': activeNote.name, // 🆕 Utiliser le nom de la sous-note
        };
        res = await ApiClient.dio.post('/orders', data: payload);
      }
      
      final newOrderId = (res.data['id'] as num?)?.toInt() ?? 0;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #$newOrderId envoyée à la cuisine ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      return newOrderId;
    } catch (e) {
      print('[POS] Erreur envoi cuisine: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Créer une note et transférer des articles
  static Future<OrderNote?> createNoteAndTransfer({
    required int activeOrderId,
    required String name,
    required int covers,
    required Map<int, int> selectedItems,
    required String currentTableNumber,
    required String activeNoteId,
    required OrderNote activeNote,
    required BuildContext context,
  }) async {
    try {
      // Valider les quantités
      for (final entry in selectedItems.entries) {
        final item = activeNote.items[entry.key];
        if (entry.value > item.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: Vous essayez de transférer ${entry.value} ${item.name} mais il n\'y en a que ${item.quantity} dans cette note'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return null;
        }
      }
      
      // Créer la nouvelle sous-note côté serveur
      final response = await ApiClient.dio.post('/orders/$activeOrderId/subnotes', data: {
        'name': name,
        'covers': covers,
        'items': [],
      });

      if (response.statusCode != 201) {
        throw Exception('Erreur création sous-note');
      }

      final serverData = response.data as Map<String, dynamic>;
      final createdNote = OrderNote.fromJson((serverData['subNote'] as Map<String, dynamic>));

      // Transférer les items
      final transferSuccess = await transferItemsDirectly(
        targetNoteId: createdNote.id,
        selectedItems: selectedItems,
        currentTableNumber: currentTableNumber,
        activeOrderId: activeOrderId,
        activeNoteId: activeNoteId,
        activeNote: activeNote,
        context: context,
      );

      if (transferSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note "$name" créée et articles transférés'),
            backgroundColor: Colors.green,
          ),
        );
        return createdNote;
      }
      
      return null;
    } catch (e) {
      print('[POS] Erreur création note: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Obtenir les tables disponibles
  static Future<List<Map<String, dynamic>>> getAvailableTables({
    required String currentTableNumber,
  }) async {
    try {
      print('[TRANSFER] _getAvailableTables appelé');
      // Récupérer toutes les commandes pour voir quelles tables existent
      final response = await ApiClient.dio.get('/orders');
      final orders = (response.data as List).cast<Map<String, dynamic>>();
      print('[TRANSFER] ${orders.length} commandes récupérées du serveur');
      
      // Grouper par table
      final tablesMap = <String, Map<String, dynamic>>{};
      for (final order in orders) {
        final tableNumber = order['table']?.toString() ?? '';
        if (tableNumber.isNotEmpty && tableNumber != currentTableNumber) {
          if (!tablesMap.containsKey(tableNumber)) {
            tablesMap[tableNumber] = {
              'number': tableNumber,
              'covers': order['covers'] ?? 1,
              'orderTotal': 0.0,
            };
          }
          // Cumuler le total
          final total = (order['total'] as num?)?.toDouble() ?? 0.0;
          tablesMap[tableNumber]!['orderTotal'] = (tablesMap[tableNumber]!['orderTotal'] as double) + total;
        }
      }
      
      final tables = tablesMap.values.toList();
      print('[TRANSFER] ${tables.length} tables disponibles trouvées: ${tables.map((t) => t['number']).join(', ')}');
      return tables;
    } catch (e) {
      print('[POS] Erreur récupération tables: $e');
      return [];
    }
  }
}

class _TransferItemGroup {
  final int orderId;
  final String noteId;
  final List<Map<String, dynamic>> items;

  _TransferItemGroup({
    required this.orderId,
    required this.noteId,
    required this.items,
  });
}

Map<String, _TransferItemGroup> _groupSelectedItems({
  required Map<int, int> selectedItems,
  required OrderNote activeNote,
  required int? fallbackOrderId,
  required String fallbackNoteId,
}) {
  final groups = <String, _TransferItemGroup>{};

  for (final entry in selectedItems.entries) {
    final index = entry.key;
    if (index < 0 || index >= activeNote.items.length) continue;
    final item = activeNote.items[index];
    final orderId = item.sourceOrderId ?? fallbackOrderId;
    final noteId = item.sourceNoteId ?? fallbackNoteId;
    if (orderId == null || noteId.isEmpty) {
      print('[TRANSFER] Impossible de déterminer la commande/note source pour ${item.name}');
      continue;
    }
    final key = '$orderId|$noteId';
    groups.putIfAbsent(key, () => _TransferItemGroup(orderId: orderId, noteId: noteId, items: []));
    groups[key]!.items.add({
      'id': item.id,
      'name': item.name,
      'price': item.price,
      'quantity': entry.value,
    });
  }

  return groups;
}

