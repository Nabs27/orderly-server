import 'package:flutter/material.dart';
import 'paid_ticket_dialog.dart';
import 'package:intl/intl.dart';

class PaidHistoryDialog extends StatefulWidget {
  final List<Map<String, dynamic>> paidPayments;

  const PaidHistoryDialog({
    super.key,
    required this.paidPayments,
  });

  @override
  State<PaidHistoryDialog> createState() => _PaidHistoryDialogState();
}

class _PaidHistoryDialogState extends State<PaidHistoryDialog> {
  String? _selectedTable;

  @override
  Widget build(BuildContext context) {
    // Regrouper les paiements par table
    final tablesMap = <String, List<Map<String, dynamic>>>{};
    for (final payment in widget.paidPayments) {
      final table = payment['table']?.toString() ?? '?';
      if (!tablesMap.containsKey(table)) {
        tablesMap[table] = [];
      }
      tablesMap[table]!.add(payment);
    }

    // Si une table est sélectionnée, afficher ses services
    if (_selectedTable != null && tablesMap.containsKey(_selectedTable)) {
      return _TableServicesDialog(
        tableNumber: _selectedTable!,
        payments: tablesMap[_selectedTable]!,
        onBack: () => setState(() => _selectedTable = null),
      );
    }

    // Sinon, afficher la liste des tables
    final sortedTables = tablesMap.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999));

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Historique des encaissements',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${sortedTables.length} table(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: sortedTables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun paiement encaissé',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: sortedTables.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tableNumber = sortedTables[index];
                        final payments = tablesMap[tableNumber]!;
                        // 🆕 Utiliser enteredAmount (montant réellement encaissé) si disponible, sinon amount
                        final totalAmount = payments.fold<double>(
                          0.0,
                          (sum, p) {
                            // Pour les split payments, utiliser enteredAmount (montant total encaissé)
                            final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
                            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                            return sum + (enteredAmount ?? amount);
                          },
                        );
                        final server = payments.first['server']?.toString() ?? 'unknown';
                        final firstPayment = payments.first;
                        final lastPayment = payments.last;
                        final firstDate = _formatDate(firstPayment['timestamp']?.toString());
                        final lastDate = _formatDate(lastPayment['timestamp']?.toString());

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(
                              tableNumber,
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            'Table $tableNumber',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              Text('Serveur: $server'),
                              Text('${payments.length} paiement(s) • $firstDate → $lastDate'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatCurrency(totalAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          onTap: () => setState(() => _selectedTable = tableNumber),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        ) + ' TND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '—';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }
}

/// Dialog pour afficher les services d'une table
class _TableServicesDialog extends StatefulWidget {
  final String tableNumber;
  final List<Map<String, dynamic>> payments;
  final VoidCallback onBack;

  const _TableServicesDialog({
    required this.tableNumber,
    required this.payments,
    required this.onBack,
  });

  @override
  State<_TableServicesDialog> createState() => _TableServicesDialogState();
}

class _TableServicesDialogState extends State<_TableServicesDialog> {
  int? _selectedServiceIndex;

  @override
  Widget build(BuildContext context) {
    // Regrouper les paiements par service (basé sur les timestamps)
    final services = _groupPaymentsByService(widget.payments);

    // Si un service est sélectionné, afficher son détail
    if (_selectedServiceIndex != null && services.containsKey(_selectedServiceIndex)) {
      return _ServiceDetailDialog(
        tableNumber: widget.tableNumber,
        serviceNumber: _selectedServiceIndex!,
        payments: services[_selectedServiceIndex]!,
        onBack: () => setState(() => _selectedServiceIndex = null),
      );
    }

    // Sinon, afficher la liste des services
    final serviceEntries = services.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // Plus récent en premier

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Table ${widget.tableNumber}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${services.length} service(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: serviceEntries.isEmpty
                  ? const Center(child: Text('Aucun service'))
                  : ListView.builder(
                      itemCount: serviceEntries.length,
                      itemBuilder: (context, index) {
                        final entry = serviceEntries[index];
                        final serviceIndex = entry.key;
                        final servicePayments = entry.value;
                        // 🆕 Utiliser enteredAmount si disponible
                        final totalAmount = servicePayments.fold<double>(
                          0.0,
                          (sum, p) {
                            final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
                            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                            return sum + (enteredAmount ?? amount);
                          },
                        );
                        final firstDate = _formatDate(servicePayments.first['timestamp']?.toString());
                        final lastDate = _formatDate(servicePayments.last['timestamp']?.toString());
                        
                        // 🆕 Détecter si c'est un paiement divisé
                        final isSplitPayment = servicePayments.isNotEmpty && 
                            servicePayments.first['isSplitPayment'] == true;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                '$serviceIndex',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('Service #$serviceIndex'),
                                if (isSplitPayment) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Paiement divisé',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$firstDate → $lastDate'),
                                const SizedBox(height: 4),
                                Text('${servicePayments.length} paiement(s) • ${_formatCurrency(totalAmount)}'),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                            onTap: () => setState(() => _selectedServiceIndex = serviceIndex),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Regroupe les paiements par service (basé sur les gaps de temps)
  /// 🆕 Les paiements divisés avec le même splitPaymentId sont toujours regroupés ensemble
  Map<int, List<Map<String, dynamic>>> _groupPaymentsByService(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return {};

    // 🆕 ÉTAPE 1: D'abord regrouper les paiements divisés par splitPaymentId
    final Map<String, List<Map<String, dynamic>>> splitPaymentGroups = {};
    final List<Map<String, dynamic>> nonSplitPayments = [];
    
    for (final payment in payments) {
      final isSplit = payment['isSplitPayment'] == true;
      final splitId = payment['splitPaymentId']?.toString();
      
      if (isSplit && splitId != null && splitId.isNotEmpty) {
        // Paiement divisé : regrouper par splitPaymentId
        if (!splitPaymentGroups.containsKey(splitId)) {
          splitPaymentGroups[splitId] = [];
        }
        splitPaymentGroups[splitId]!.add(payment);
      } else {
        // Paiement normal : ajouter à la liste
        nonSplitPayments.add(payment);
      }
    }
    
    // 🆕 ÉTAPE 2: Créer une liste consolidée où chaque groupe de paiements divisés est traité comme un seul paiement
    final List<Map<String, dynamic>> consolidatedPayments = [];
    
    // Ajouter les groupes de paiements divisés (un seul "paiement" par groupe)
    for (final group in splitPaymentGroups.values) {
      if (group.isNotEmpty) {
        // Utiliser le premier paiement comme représentant du groupe (ils ont tous le même timestamp)
        consolidatedPayments.add(group.first);
      }
    }
    
    // Ajouter les paiements normaux
    consolidatedPayments.addAll(nonSplitPayments);
    
    // 🆕 ÉTAPE 3: Trier par timestamp
    consolidatedPayments.sort((a, b) {
      final timeA = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
      final timeB = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
      return timeA.compareTo(timeB);
    });

    // 🆕 ÉTAPE 4: Regrouper par service (gaps de temps)
    final Map<int, List<Map<String, dynamic>>> services = {};
    int currentServiceIndex = 0;
    DateTime? lastPaymentTime;

    const serviceGapMinutes = 30; // Gap de 30 minutes = nouveau service

    for (final payment in consolidatedPayments) {
      final timestamp = payment['timestamp']?.toString();
      if (timestamp == null) continue;

      final paymentTime = DateTime.tryParse(timestamp);
      if (paymentTime == null) continue;

      bool isNewService = false;
      if (lastPaymentTime == null) {
        isNewService = true;
      } else {
        final gap = paymentTime.difference(lastPaymentTime);
        if (gap.inMinutes > serviceGapMinutes) {
          isNewService = true;
        }
      }

      if (isNewService) {
        currentServiceIndex++;
        services[currentServiceIndex] = [];
      }

      // 🆕 Si c'est un paiement divisé, ajouter TOUS les paiements du groupe
      final isSplit = payment['isSplitPayment'] == true;
      final splitId = payment['splitPaymentId']?.toString();
      
      if (isSplit && splitId != null && splitId.isNotEmpty && splitPaymentGroups.containsKey(splitId)) {
        // Ajouter tous les paiements du groupe divisé
        services[currentServiceIndex]!.addAll(splitPaymentGroups[splitId]!);
      } else {
        // Ajouter le paiement normal
        services[currentServiceIndex]!.add(payment);
      }
      
      lastPaymentTime = paymentTime;
    }

    return services;
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        ) + ' TND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '—';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }
}

/// Dialog pour afficher le détail d'un service avec ticket principal et tickets secondaires
class _ServiceDetailDialog extends StatelessWidget {
  final String tableNumber;
  final int serviceNumber;
  final List<Map<String, dynamic>> payments;
  final VoidCallback onBack;

  const _ServiceDetailDialog({
    required this.tableNumber,
    required this.serviceNumber,
    required this.payments,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Calculer le nombre de commandes distinctes dans ce service
    final distinctOrderIds = payments.map((p) => p['orderId'] ?? p['sessionId']).toSet().where((id) => id != null).toSet();
    final nbOrders = distinctOrderIds.length > 0 ? distinctOrderIds.length : 1;

    // Calculer le total du service
    // 🆕 Utiliser enteredAmount (montant encaissé) si disponible
    // ⚠️ IMPORTANT: Diviser par nbOrders car chaque transaction est répétée pour chaque commande du service
    final totalAmountRaw = payments.fold<double>(
      0.0,
      (sum, p) {
        final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + (enteredAmount ?? amount);
      },
    );
    final totalAmount = totalAmountRaw / nbOrders;

    // Créer le ticket principal (consolidé)
    final allItems = <Map<String, dynamic>>[];
    double totalSubtotal = 0.0;
    double totalDiscountAmount = 0.0;
    
    // 🆕 Détecter si c'est un paiement divisé (même splitPaymentId)
    final isSplitPayment = payments.isNotEmpty && 
        payments.first['isSplitPayment'] == true &&
        payments.first['splitPaymentId'] != null;
    
    // 🆕 Pour paiement divisé, ne prendre les articles qu'une seule fois (du premier paiement)
    // car tous les paiements divisés ont les mêmes articles
    if (isSplitPayment && payments.isNotEmpty) {
      final firstPayment = payments.first;
      final items = (firstPayment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final item in items) {
        allItems.add(Map<String, dynamic>.from(item));
      }
      // 🆕 CORRECTION: Calculer le subtotal depuis les articles, pas depuis firstPayment['subtotal']
      // car firstPayment['subtotal'] est le allocatedAmount (montant proportionnel), pas le sous-total du ticket
      totalSubtotal = allItems.fold<double>(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        return sum + (price * quantity);
      });
      // Pour la remise, prendre celle du paiement (ou 0 si non disponible)
      // Note: discountAmount dans firstPayment est aussi proportionnel, donc on recalcule si nécessaire
      final discountRate = (firstPayment['discount'] as num?)?.toDouble() ?? 0.0;
      final isPercentDiscount = firstPayment['isPercentDiscount'] == true;
      if (isPercentDiscount && discountRate > 0) {
        totalDiscountAmount = totalSubtotal * (discountRate / 100);
      } else {
        totalDiscountAmount = discountRate; // Remise fixe
      }
    } else {
      // 🆕 Paiement normal : consolider les articles de tous les paiements
      for (final payment in payments) {
        final items = (payment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final item in items) {
          final existingIndex = allItems.indexWhere(
            (i) => i['id'] == item['id'] && i['name'] == item['name'],
          );
          if (existingIndex != -1) {
            allItems[existingIndex]['quantity'] = (allItems[existingIndex]['quantity'] as int) + (item['quantity'] as int? ?? 0);
          } else {
            allItems.add(Map<String, dynamic>.from(item));
          }
        }
      }
      // 🐛 BUG FIX : Recalculer le subtotal depuis les articles agrégés (au lieu d'additionner les subtotals)
      // car si plusieurs paiements concernent la même table avec remises, on additionne les remises plusieurs fois
      totalSubtotal = allItems.fold<double>(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        return sum + (price * quantity);
      });
      // 🐛 BUG FIX : Additionner les remises RÉELLES de tous les paiements
      // Ne PAS appliquer un pourcentage au total si seulement une partie des paiements a une remise
      if (payments.isNotEmpty) {
        // 🆕 Additionner les discountAmount réels de tous les paiements qui ont une remise
        double sumDiscountAmounts = 0.0;
        Map<String, dynamic>? firstPaymentWithDiscount;
        Set<String> discountRates = {}; // Pour vérifier si tous les paiements ont la même remise
        
        for (final payment in payments) {
          final paymentDiscountAmount = (payment['discountAmount'] as num?)?.toDouble() ?? 0.0;
          if (paymentDiscountAmount > 0.01) {
            sumDiscountAmounts += paymentDiscountAmount;
            if (firstPaymentWithDiscount == null) {
              firstPaymentWithDiscount = payment;
            }
            // 🆕 Enregistrer le taux de remise pour vérifier l'uniformité
            final paymentDiscount = (payment['discount'] as num?)?.toDouble() ?? 0.0;
            final isPercent = payment['isPercentDiscount'] == true;
            if (paymentDiscount > 0.01) {
              discountRates.add('${isPercent ? 'PCT' : 'FIX'}_${paymentDiscount.toStringAsFixed(2)}');
            }
          }
        }
        
        // 🆕 Utiliser la somme des remises réelles (pas un recalcul trompeur)
        totalDiscountAmount = sumDiscountAmounts;
      }
    }

    // 🆕 Collecter les modes de paiement pour paiement divisé
    String? paymentModeDisplay = 'MIXTE';
    if (isSplitPayment) {
      final modes = payments.map((p) => p['paymentMode']?.toString() ?? '').where((m) => m.isNotEmpty).toSet();
      if (modes.length == 1) {
        paymentModeDisplay = modes.first;
      } else {
        paymentModeDisplay = 'MIXTE (${modes.length} modes)';
      }
    }
    
    // 🆕 CORRECTION: Le total du ticket = subtotal - remise (pas le montant encaissé)
    final ticketTotal = totalSubtotal - totalDiscountAmount;
    
    // 🆕 Calculer le taux RÉEL de remise basé sur le totalSubtotal et totalDiscountAmount
    // (au lieu d'afficher le taux d'un paiement qui pourrait être trompeur)
    // Exemple : si remise de 23.28 TND sur 291 TND = 8% réel, pas 15%
    double discountRate = 0.0;
    bool isPercentDiscount = false;
    if (totalDiscountAmount > 0.01 && totalSubtotal > 0.01) {
      // 🆕 Calculer le taux réel : (remise / sous-total) * 100
      discountRate = (totalDiscountAmount / totalSubtotal) * 100;
      isPercentDiscount = true; // Toujours en pourcentage pour le taux réel
    }
    
    // 🆕 Calculer le pourboire total : montant encaissé - montant du ticket
    // C'est la méthode la plus simple et fiable (comme dans history-processor.js)
    // totalAmount = somme des enteredAmount (montant réellement encaissé)
    // ticketTotal = subtotal - remise (montant du ticket)
    double totalExcessAmount = 0.0;
    
    // 🆕 Vérifier si du liquide est présent dans les paiements
    bool hasCashInPayment = false;
    for (final payment in payments) {
      if (payment['hasCashInPayment'] == true) {
        hasCashInPayment = true;
        break;
      }
    }
    
    // 🆕 Pourboire = montant encaissé - montant du ticket (seulement si pas de cash)
    // Si du cash est présent, le pourboire est pris directement du cash (pas comptabilisé)
    if (!hasCashInPayment && totalAmount > ticketTotal) {
      totalExcessAmount = totalAmount - ticketTotal;
    }
    
    // 🆕 Collecter les détails des paiements (modes et montants encaissés)
    final paymentDetails = <Map<String, dynamic>>[];
    
    // 🆕 Faire un comptage précis de chaque transaction
    final Map<String, int> txCounts = {};
    final Map<String, Map<String, dynamic>> txData = {};
    
    for (final payment in payments) {
      final enteredAmount = (payment['enteredAmount'] as num?)?.toDouble() ?? 
          ((payment['amount'] as num?)?.toDouble() ?? 0.0);
      final paymentMode = payment['paymentMode']?.toString() ?? '';
      
      // 🆕 PRIORITÉ: transactionId pour les nouveaux paiements
      // Fallback: _id (ID unique du record en DB) pour ne JAMAIS fusionner par erreur
      final transactionId = payment['transactionId']?.toString();
      final recordId = payment['_id']?.toString() ?? payment['id']?.toString();
      final txKey = transactionId != null 
          ? 'tx_$transactionId' 
          : (recordId != null ? 'id_$recordId' : '${paymentMode}_${enteredAmount.toStringAsFixed(3)}_${payment['timestamp']}');
          
      if (!txCounts.containsKey(txKey)) {
        txCounts[txKey] = 0;
        txData[txKey] = {
          'mode': paymentMode,
          'amount': enteredAmount,
          'clientName': (paymentMode == 'CREDIT' && payment['creditClientName'] != null) 
              ? payment['creditClientName'].toString() 
              : null,
        };
      }
      txCounts[txKey] = txCounts[txKey]! + 1;
    }
    
    // 🆕 Ajouter chaque transaction (count / nbOrders) fois
    for (final entry in txCounts.entries) {
      final key = entry.key;
      final count = entry.value;
      final numAppearances = (count / nbOrders).round();
      
      for (int i = 0; i < numAppearances; i++) {
        paymentDetails.add(txData[key]!);
      }
    }
    
    final mainTicket = {
      'table': tableNumber,
      'date': payments.first['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'items': allItems,
      'subtotal': totalSubtotal,
      'discount': discountRate, // 🆕 Taux RÉEL calculé (remise / sous-total * 100)
      'isPercentDiscount': isPercentDiscount, // 🆕 Toujours true pour le taux réel
      'discountAmount': totalDiscountAmount,
      'total': ticketTotal, // 🆕 Total du ticket (subtotal - remise), pas le montant encaissé
      'excessAmount': totalExcessAmount > 0.01 ? totalExcessAmount : null, // 🆕 Pourboire total
      'covers': payments.first['covers'] ?? 1,
      'server': payments.first['server'] ?? 'unknown',
      'paymentMode': paymentModeDisplay,
      'isSplitPayment': isSplitPayment, // 🆕 Indicateur de paiement divisé
      'paymentDetails': paymentDetails, // 🆕 Détails des paiements (modes et montants)
      'totalAmount': totalAmount, // 🆕 Montant total encaissé
    };

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Table $tableNumber - Service #$serviceNumber',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticket principal
                    Card(
                      elevation: 3,
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.receipt_long, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ticket Principal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total: ${_formatCurrency(ticketTotal)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            // 🆕 Afficher le pourboire si présent
                            if (totalExcessAmount > 0.01) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Pourboire ${(payments.first['server']?.toString() ?? 'unknown').toUpperCase()}: ${_formatCurrency(totalExcessAmount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Montant encaissé: ${_formatCurrency(totalAmount)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => PaidTicketDialog(ticket: mainTicket),
                                );
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Voir le ticket principal'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tickets secondaires (un par paiement)
                    const Text(
                      'Tickets de paiement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...payments.map((payment) {
                      final noteName = payment['noteName']?.toString() ?? 'Note Principale';
                      final paymentMode = payment['paymentMode']?.toString() ?? 'N/A';
                      final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                      final ticket = payment['ticket'] as Map<String, dynamic>?;
                      final isSplitPayment = payment['isSplitPayment'] == true;
                      
                      // 🆕 Créer le ticket dynamiquement pour les split payments en utilisant les valeurs du backend
                      // Le backend a déjà calculé correctement subtotal, discountAmount, amount (ticketAmount) et items
                      final effectiveTicket = ticket ?? (isSplitPayment ? {
                        'table': payment['table']?.toString() ?? '—',
                        'date': payment['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
                        'items': (payment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                        'subtotal': (payment['subtotal'] as num?)?.toDouble() ?? 0.0,  // ✅ Utiliser subtotal du backend (déjà calculé depuis articles)
                        'discount': (payment['discount'] as num?)?.toDouble() ?? 0.0,
                        'discountAmount': (payment['discountAmount'] as num?)?.toDouble() ?? 0.0,  // ✅ Utiliser discountAmount du backend
                        'isPercentDiscount': payment['isPercentDiscount'] == true,
                        'total': (payment['amount'] as num?)?.toDouble() ?? 0.0,  // ✅ Utiliser amount (ticketAmount = subtotal - remise) du backend
                        'covers': payment['covers'] ?? 1,
                        'server': payment['server']?.toString() ?? 'unknown',
                        'paymentMode': payment['paymentMode']?.toString(),
                        'isSplitPayment': true,
                      } : null);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              paymentMode == 'ESPECE' ? Icons.money : Icons.credit_card,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('$noteName • ${_getPaymentModeLabel(paymentMode)}'),
                              ),
                              if (isSplitPayment) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Divisé',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(_formatDate(payment['timestamp']?.toString())),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatCurrency(amount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (effectiveTicket != null)
                                IconButton(
                                  icon: const Icon(Icons.receipt_long),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => PaidTicketDialog(ticket: effectiveTicket),
                                    );
                                  },
                                  tooltip: 'Voir le ticket',
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        ) + ' TND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '—';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }

  String _getPaymentModeLabel(String? mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
        return 'Carte';
      case 'CHEQUE':
        return 'Chèque';
      case 'TPE':
        return 'TPE';
      default:
        return mode ?? '—';
    }
  }
}
