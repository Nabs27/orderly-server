import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';
import 'tables_repository.dart';

class OrdersSyncService {
  static Future<void> syncOrdersWithTables(Map<String, List<Map<String, dynamic>>> serverTables) async {
    try {
      final response = await ApiClient.dio.get('/orders');
      final orders = (response.data as List).cast<Map<String, dynamic>>();

      print('[SYNC] 📥 ${orders.length} commandes chargées depuis le serveur');
      
      // 🆕 Log des commandes client
      final clientOrders = orders.where((o) => o['source'] == 'client').toList();
      if (clientOrders.isNotEmpty) {
        print('[SYNC] 🆕 ${clientOrders.length} commande(s) client trouvée(s):');
        for (final order in clientOrders) {
          // 🆕 CORRECTION : Afficher tempId si id est null (commandes client sans ID officiel)
          final orderId = order['id'] ?? order['tempId'] ?? 'sans ID';
          print('[SYNC]   - Commande $orderId: table=${order['table']}, status=${order['status']}, server=${order['server']}, total=${order['total']}');
        }
      }

      if (orders.isEmpty) {
        serverTables.clear();
        return;
      }

      final ordersByTableAndServer = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final order in orders) {
        final tableNumber = order['table']?.toString() ?? '';
        final server = order['server']?.toString() ?? 'MOHAMED';
        if (tableNumber.isNotEmpty) {
          ordersByTableAndServer.putIfAbsent(tableNumber, () => {});
          ordersByTableAndServer[tableNumber]!.putIfAbsent(server, () => []).add(order);
        }
      }

      final ordersByTable = <String, List<Map<String, dynamic>>>{};
      for (final tableNumber in ordersByTableAndServer.keys) {
        final allOrdersForTable = <Map<String, dynamic>>[];
        for (final serverOrders in ordersByTableAndServer[tableNumber]!.values) {
          allOrdersForTable.addAll(serverOrders);
        }
        ordersByTable[tableNumber] = allOrdersForTable;
      }

      // Créer tables manquantes
      for (final tableNumber in ordersByTable.keys) {
        final tableOrders = ordersByTable[tableNumber]!;
        if (tableOrders.isNotEmpty) {
          final firstOrder = tableOrders.first;
          final server = firstOrder['server'] as String? ?? 'MOHAMED';
          final existingTables = serverTables[server] ?? [];
          final exists = existingTables.any((t) => t['number'] == tableNumber);
          if (!exists) {
            final mainNoteData = firstOrder['mainNote'] as Map<String, dynamic>?;
            final inferredCovers = (mainNoteData != null
                ? (mainNoteData['covers'] as num?)
                : firstOrder['covers'] as num?)?.toInt() ?? 1;
            final newTable = {
              'id': 'table_${server}_$tableNumber',
              'number': tableNumber,
              'status': 'occupee',
              'server': server,
              'covers': inferredCovers,
              'openedAt': DateTime.now(),
              'orderId': null,
              'orderTotal': 0.0,
              'orderItems': [],
              'lastOrderAt': DateTime.now(),
              'activeNotesCount': 0,
            };
            serverTables[server] ??= [];
            serverTables[server]!.add(newTable);
          }
        }
      }

      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        for (final table in tables) {
          final tableNumber = table['number'] as String;
          final tableOrders = ordersByTableAndServer[tableNumber]?[serverName] ?? [];
          if (tableOrders.isNotEmpty) {
            double total = 0.0;
            for (final order in tableOrders) {
              // 🆕 Log pour debug
              // 🆕 CORRECTION : Afficher tempId si id est null (commandes client sans ID officiel)
              final orderId = order['id'] ?? order['tempId'] ?? 'sans ID';
              final orderSource = order['source'] as String?;
              final orderStatus = order['status'] as String?;
              final serverConfirmed = order['serverConfirmed'] as bool?;
              print('[SYNC] Commande $orderId: source=$orderSource, status=$orderStatus, serverConfirmed=$serverConfirmed');
              
              if (order.containsKey('mainNote') && order['mainNote'] != null) {
                final mainNote = order['mainNote'] as Map<String, dynamic>;
                final mainTotal = (mainNote['total'] as num?)?.toDouble() ?? 0.0;
                final mainPaid = (mainNote['paid'] as bool?) ?? false;
                
                // 🆕 Inclure la note principale seulement si elle n'est pas payée
                // Les commandes en attente ont mainNote.paid = false, donc elles seront incluses
                if (!mainPaid && mainTotal > 0) {
                  total += mainTotal;
                  print('[SYNC] ✅ Ajouté mainNote total: $mainTotal (commande $orderId, source=$orderSource)');
                } else {
                  print('[SYNC] ⏭️ MainNote ignorée: paid=$mainPaid, total=$mainTotal (commande $orderId)');
                }
                
                final subNotes = (order['subNotes'] as List?) ?? [];
                for (final subNote in subNotes) {
                  final subTotal = (subNote['total'] as num?)?.toDouble() ?? 0.0;
                  final isPaid = (subNote['paid'] as bool?) ?? false;
                  if (!isPaid && subTotal > 0) {
                    total += subTotal;
                    print('[SYNC] ✅ Ajouté sous-note total: $subTotal (commande $orderId)');
                  }
                }
              } else {
                // Ancienne structure sans mainNote
                final orderTotal = (order['total'] as num?)?.toDouble() ?? 0.0;
                total += orderTotal;
                print('[SYNC] ✅ Ajouté total (ancienne structure): $orderTotal (commande $orderId)');
              }
            }
            print('[SYNC] 📊 Total calculé pour table $tableNumber (serveur $serverName): $total TND');
            // Trouver la commande la plus récente par createdAt (pour orderId et covers)
            final latestOrder = tableOrders.reduce((a, b) =>
                DateTime.parse(a['createdAt'] as String).isAfter(DateTime.parse(b['createdAt'] as String)) ? a : b);
            final latestMain = latestOrder['mainNote'] as Map<String, dynamic>?;
            final syncedCovers = (latestMain != null
                    ? (latestMain['covers'] as num?)
                    : latestOrder['covers'] as num?)
                ?.toInt();
            if (syncedCovers != null && syncedCovers > 0) {
              table['covers'] = syncedCovers;
            }
            
            final allItems = <Map<String, dynamic>>[];
            int activeNotesCount = 0;
            DateTime? latestActivity = null; // Dernière activité parmi toutes les commandes
            bool mainNoteCounted = false;
            final countedSubNoteIds = <String>{};
            
            // 🆕 Détecter les commandes client en attente de confirmation
            bool hasPendingClientOrders = false;
            String? pendingClientOrderServer;
            String? pendingClientOrderId; // 🆕 String pour accepter tempId (commandes client sans ID)
            
            // 🆕 Détecter les nouvelles commandes client (créées il y a moins de 30 secondes)
            bool hasNewClientOrder = false;
            String? newClientOrderId; // 🆕 String pour accepter tempId (commandes client sans ID)
            DateTime? newClientOrderTime;
            
            for (final order in tableOrders) {
              // 🆕 Vérifier si c'est une commande client en attente
              // 🆕 CORRECTION : Les commandes confirmées deviennent source='pos', donc pas besoin de les filtrer
              final source = order['source'] as String?;
              final status = order['status'] as String?;
              final serverConfirmed = order['serverConfirmed'] as bool?;
              
              // 🆕 Seules les commandes avec source='client' et status='pending_server_confirmation' sont en attente
              // Les commandes confirmées deviennent source='pos' donc elles sont traitées comme des commandes normales
              if (source == 'client' && 
                  status == 'pending_server_confirmation' && 
                  (serverConfirmed == false || serverConfirmed == null)) {
                hasPendingClientOrders = true;
                pendingClientOrderServer = order['server'] as String?;
                // 🆕 CORRECTION : Utiliser tempId si id est null (commandes client sans ID officiel)
                pendingClientOrderId = (order['id'] as int?)?.toString() ?? order['tempId'] as String?;
                
                // 🆕 Vérifier si c'est une nouvelle commande (créée il y a moins de 30 secondes)
                final createdAt = order['createdAt'] as String?;
                if (createdAt != null) {
                  final createdDateTime = DateTime.tryParse(createdAt);
                  if (createdDateTime != null) {
                    final now = DateTime.now();
                    final difference = now.difference(createdDateTime);
                    if (difference.inSeconds < 30) {
                      hasNewClientOrder = true;
                      // 🆕 CORRECTION : Utiliser tempId si id est null (commandes client sans ID officiel)
                      newClientOrderId = (order['id'] as int?)?.toString() ?? order['tempId'] as String?;
                      newClientOrderTime = createdDateTime;
                      
                      // 🆕 Récupérer les articles de la commande client pour affichage
                      final mainNote = order['mainNote'] as Map<String, dynamic>?;
                      final clientOrderItems = <Map<String, dynamic>>[];
                      if (mainNote != null) {
                        final items = (mainNote['items'] as List?) ?? [];
                        clientOrderItems.addAll(items.cast<Map<String, dynamic>>());
                      }
                      // Stocker pour affichage dans TableCard
                      table['newClientOrderItems'] = clientOrderItems;
                    }
                  }
                }
                
                break; // Prendre la première commande en attente trouvée
              }
              // Calculer l'activité de cette commande (max entre updatedAt et createdAt)
              DateTime? orderActivity;
              final orderUpdatedAt = order['updatedAt'] as String?;
              final orderCreatedAt = order['createdAt'] as String?;
              
              if (orderUpdatedAt != null) {
                orderActivity = DateTime.tryParse(orderUpdatedAt);
              } else if (orderCreatedAt != null) {
                orderActivity = DateTime.tryParse(orderCreatedAt);
              }
              
              // Mettre à jour latestActivity avec la dernière activité trouvée
              if (orderActivity != null && (latestActivity == null || orderActivity.isAfter(latestActivity))) {
                latestActivity = orderActivity;
              }
              
              if (order.containsKey('mainNote') && order['mainNote'] != null) {
                final mainNote = order['mainNote'] as Map<String, dynamic>;
                final mainItems = (mainNote['items'] as List?) ?? [];
                final mainTotal = (mainNote['total'] as num?)?.toDouble() ?? 0.0;
                final mainPaid = (mainNote['paid'] as bool?) ?? false;
                
                // Compter la note principale une seule fois si elle a des articles non payés
                if (!mainNoteCounted && mainTotal > 0 && !mainPaid && mainItems.isNotEmpty) {
                  activeNotesCount++;
                  mainNoteCounted = true;
                }
                
                allItems.addAll(mainItems.cast<Map<String, dynamic>>());
                final subNotes = (order['subNotes'] as List?) ?? [];
                
                // Compter les sous-notes actives
                for (final subNote in subNotes) {
                  final subNoteId = subNote['id'] as String? ?? '';
                  final subItems = (subNote['items'] as List?) ?? [];
                  final subTotal = (subNote['total'] as num?)?.toDouble() ?? 0.0;
                  final isPaid = (subNote['paid'] as bool?) ?? false;
                  
                  // Compter chaque sous-note une seule fois si elle est active
                  if (!countedSubNoteIds.contains(subNoteId) && !isPaid && subTotal > 0 && subItems.isNotEmpty) {
                    activeNotesCount++;
                    countedSubNoteIds.add(subNoteId);
                  }
                  
                  if (!isPaid && subTotal > 0 && subItems.isNotEmpty) {
                    allItems.addAll(subItems.cast<Map<String, dynamic>>());
                  }
                }
              } else {
                // Pour les commandes sans structure de notes, compter comme une seule note
                final items = (order['items'] as List?) ?? [];
                final orderTotal = (order['total'] as num?)?.toDouble() ?? 0.0;
                if (orderTotal > 0 && items.isNotEmpty && !mainNoteCounted) {
                  activeNotesCount++;
                  mainNoteCounted = true;
                }
                allItems.addAll(items.cast<Map<String, dynamic>>());
              }
            }
            
            table['orderId'] = latestOrder['id'];
            table['orderTotal'] = total;
            table['orderItems'] = allItems;
            table['activeNotesCount'] = activeNotesCount;
            
            // 🆕 Ajouter les informations sur les commandes client en attente
            table['hasPendingClientOrders'] = hasPendingClientOrders;
            if (hasPendingClientOrders) {
              table['pendingClientOrderServer'] = pendingClientOrderServer;
              table['pendingClientOrderId'] = pendingClientOrderId;
            }
            
            // 🆕 Ajouter l'information sur les nouvelles commandes
            table['hasNewClientOrder'] = hasNewClientOrder;
            if (hasNewClientOrder) {
              table['newClientOrderId'] = newClientOrderId;
              table['newClientOrderTime'] = newClientOrderTime?.toIso8601String();
            }
            
            // Utiliser latestActivity (déjà calculé pour toutes les commandes)
            table['lastOrderAt'] = latestActivity ?? 
                (latestOrder['createdAt'] != null 
                    ? DateTime.tryParse(latestOrder['createdAt'] as String) ?? DateTime.now()
                    : DateTime.now());
          } else {
            table['orderId'] = null;
            table['orderTotal'] = 0.0;
            table['orderItems'] = [];
            table['activeNotesCount'] = 0;
            table['hasPendingClientOrders'] = false;
            table['hasNewClientOrder'] = false;
            // Ne pas modifier lastOrderAt si la table n'a pas de commandes
          }
        }
      }

      // Supprimer les tables sans commandes pour ce serveur
      final tablesToRemove = <String, List<String>>{};
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        final toDelete = <String>[];
        for (final table in tables) {
          final tableNumber = table['number'] as String;
          bool hasOrdersForThisServer = false;
          if (ordersByTableAndServer.containsKey(tableNumber)) {
            hasOrdersForThisServer = ordersByTableAndServer[tableNumber]!.containsKey(serverName) &&
                ordersByTableAndServer[tableNumber]![serverName]!.isNotEmpty;
          }
          if (!hasOrdersForThisServer) {
            toDelete.add(tableNumber);
          }
        }
        if (toDelete.isNotEmpty) tablesToRemove[serverName] = toDelete;
      }
      for (final serverName in tablesToRemove.keys) {
        final toDelete = tablesToRemove[serverName]!;
        serverTables[serverName]!.removeWhere((t) => toDelete.contains(t['number'] as String));
      }

      // Après avoir synchronisé chaque table avec l'API, si aucune commande n'est trouvée pour une table donnée,
      // la marquer comme libre et la retirer de l'affichage (bonne pratique POS : table payée disparaît du plan).
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName] ?? [];
        final toRemove = <Map<String, dynamic>>[];
        for (final table in tables) {
          final total = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
          final items = (table['orderItems'] as List?) ?? const [];
          final status = (table['status'] as String?) ?? 'occupee';
          // Heuristique: si la synchronisation a mis orderTotal=0 et aucun item après rechargement → aucune commande active
          if (total <= 0.0001 && items.isEmpty && status != 'libre') {
            toRemove.add(table);
          }
        }
        if (toRemove.isNotEmpty) {
          for (final t in toRemove) {
            tables.remove(t);
          }
          await TablesRepository.saveAll(serverTables);
        }
      }

    } catch (_) {
      // En cas d'erreur, réinitialiser les totaux
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        for (final table in tables) {
          table['orderId'] = null;
          table['orderTotal'] = 0.0;
          table['orderItems'] = [];
          table['activeNotesCount'] = 0;
        }
      }
    }
  }
}
