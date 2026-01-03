import 'package:flutter/material.dart';
import '../services/history_service.dart';

/// Dialog pour afficher l'historique détaillé d'une table avec séparation par services
class TableHistoryDialog extends StatefulWidget {
  final String tableNumber;
  final Map<String, dynamic> processedTables; // 🆕 Données pré-traitées du serveur
  final DateTime selectedDate; // 🆕 Date sélectionnée pour filtrer les services

  const TableHistoryDialog({
    super.key,
    required this.tableNumber,
    required this.processedTables,
    required this.selectedDate,
  });

  @override
  State<TableHistoryDialog> createState() => _TableHistoryDialogState();
}

class _TableHistoryDialogState extends State<TableHistoryDialog> {
  int? _selectedServiceIndex; // null = vue liste des services, sinon index du service sélectionné

  @override
  Widget build(BuildContext context) {
    // 🆕 Utiliser les données pré-traitées du serveur depuis processedTables
    final tableData = widget.processedTables[widget.tableNumber];
    if (tableData == null) {
      return AlertDialog(
        title: Text('Historique - Table ${widget.tableNumber}'),
        content: const Text('Aucune donnée disponible pour cette table'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      );
    }
    
    final services = tableData['services'] as Map<String, dynamic>? ?? {};
    
    // Si un service est sélectionné, afficher son détail
    if (_selectedServiceIndex != null && services.containsKey(_selectedServiceIndex.toString())) {
      return _ServiceDetailDialog(
        tableNumber: widget.tableNumber,
        serviceNumber: _selectedServiceIndex!,
        serviceData: services[_selectedServiceIndex.toString()] as Map<String, dynamic>,
        onBack: () => setState(() => _selectedServiceIndex = null),
      );
    }
    
    // Sinon, afficher la liste des services (filtrés par date)
    return _ServicesListDialog(
      tableNumber: widget.tableNumber,
      services: services,
      selectedDate: widget.selectedDate, // 🆕 Passer la date sélectionnée
      onSelectService: (index) => setState(() => _selectedServiceIndex = index),
    );
  }
}

/// Dialog pour afficher la liste des services d'une table
class _ServicesListDialog extends StatelessWidget {
  final String tableNumber;
  final Map<String, dynamic> services; // 🆕 Services avec données pré-traitées
  final DateTime selectedDate; // 🆕 Date sélectionnée pour filtrer les services
  final Function(int) onSelectService;

  const _ServicesListDialog({
    required this.tableNumber,
    required this.services,
    required this.selectedDate,
    required this.onSelectService,
  });
  
  // 🆕 Fonction pour vérifier si un service appartient à la date sélectionnée
  bool _isServiceInSelectedDate(Map<String, dynamic> serviceData) {
    final sessions = serviceData['sessions'] as List? ?? [];
    if (sessions.isEmpty) return false;
    
    // Vérifier si au moins une session du service correspond à la date sélectionnée
    for (final session in sessions) {
      final sessionMap = Map<String, dynamic>.from(session as Map);
      final archivedAtStr = sessionMap['archivedAt'] ?? sessionMap['createdAt'];
      if (archivedAtStr == null) continue;
      
      try {
        final archivedAt = DateTime.parse(archivedAtStr);
        final sessionDate = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
        final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        
        if (sessionDate == selectedDateOnly) {
          return true; // Au moins une session correspond à la date sélectionnée
        }
      } catch (e) {
        continue; // Ignorer les sessions avec des dates invalides
      }
    }
    
    return false; // Aucune session ne correspond à la date sélectionnée
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 Filtrer les services par date sélectionnée
    final filteredServices = <String, Map<String, dynamic>>{};
    services.forEach((serviceKey, serviceData) {
      if (_isServiceInSelectedDate(serviceData as Map<String, dynamic>)) {
        filteredServices[serviceKey] = serviceData;
      }
    });
    
    final serviceEntries = filteredServices.entries.toList()
      ..sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key))); // Plus récent en premier

    return AlertDialog(
      title: Text('Historique - Table $tableNumber'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.7,
        child: serviceEntries.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun service enregistré',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: serviceEntries.length,
                itemBuilder: (context, index) {
                  final entry = serviceEntries[index];
                  final serviceIndex = int.parse(entry.key);
                  final serviceData = entry.value as Map<String, dynamic>;
                  
                  // 🆕 Utiliser les stats pré-calculées
                  final stats = serviceData['stats'] as Map<String, dynamic>? ?? {};
                  final totalOrders = stats['totalOrders'] as int? ?? 0;
                  final totalPayments = stats['totalPayments'] as int? ?? 0;
                  final totalAmount = (stats['totalAmount'] as num?)?.toDouble() ?? 0.0;
                  
                  // Dates du service (depuis les sessions)
                  final sessions = serviceData['sessions'] as List? ?? [];
                  if (sessions.isEmpty) return const SizedBox.shrink();
                  
                  final firstSession = sessions.first as Map<String, dynamic>;
                  final lastSession = sessions.last as Map<String, dynamic>;
                  final startDate = HistoryService.formatDate(firstSession['createdAt']);
                  final endDate = HistoryService.formatDate(lastSession['archivedAt'] ?? lastSession['createdAt']);
                  
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
                      title: Text('Service #$serviceIndex'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$startDate → $endDate'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildServiceStatChip('$totalOrders cmd', Icons.restaurant_menu),
                              const SizedBox(width: 4),
                              _buildServiceStatChip('$totalPayments pay', Icons.payment),
                              const SizedBox(width: 4),
                              _buildServiceStatChip('${totalAmount.toStringAsFixed(2)} TND', Icons.attach_money),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.blue.shade700),
                      onTap: () => onSelectService(serviceIndex),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildServiceStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// Dialog pour afficher le détail d'un service spécifique
class _ServiceDetailDialog extends StatelessWidget {
  final String tableNumber;
  final int serviceNumber;
  final Map<String, dynamic> serviceData; // 🆕 Données pré-traitées du serveur
  final VoidCallback onBack;

  const _ServiceDetailDialog({
    required this.tableNumber,
    required this.serviceNumber,
    required this.serviceData,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Utiliser les données pré-traitées du serveur
    final mergedOrderEvents = List<Map<String, dynamic>>.from(serviceData['mergedOrderEvents'] ?? []);
    final cancellationEvents = List<Map<String, dynamic>>.from(serviceData['cancellationEvents'] ?? []); // 🆕 Événements d'annulation
    final groupedPayments = List<Map<String, dynamic>>.from(serviceData['groupedPayments'] ?? []);
    final mainTicket = serviceData['mainTicket'] as Map<String, dynamic>?; // 🆕 Ticket principal
    final stats = serviceData['stats'] as Map<String, dynamic>? ?? {};
    
    final totalOrders = stats['totalOrders'] as int? ?? 0;
    final totalSubNotes = stats['totalSubNotes'] as int? ?? 0;
    final totalPayments = stats['totalPayments'] as int? ?? 0;
    final totalAmount = (stats['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return AlertDialog(
      title: Text('Table $tableNumber - Service #$serviceNumber'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        child: _buildSummaryCard(totalOrders, totalSubNotes, totalPayments, totalAmount, mainTicket, context),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              tooltip: 'Retour aux services',
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int orders, int subNotes, int payments, double total, Map<String, dynamic>? mainTicket, BuildContext context) {
    final mergedOrderEvents = List<Map<String, dynamic>>.from(serviceData['mergedOrderEvents'] ?? []);
    final cancellationEvents = List<Map<String, dynamic>>.from(serviceData['cancellationEvents'] ?? []); // 🆕 Événements d'annulation
    final groupedPayments = List<Map<String, dynamic>>.from(serviceData['groupedPayments'] ?? []);
    final sessions = List<Map<String, dynamic>>.from(serviceData['sessions'] ?? []);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total principal - SIMPLE ET VISIBLE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade400, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  'TOTAL ENCAISSÉ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${total.toStringAsFixed(2)} TND',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                    color: Colors.green.shade700,
                  ),
                ),
                if (mainTicket != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _showMainTicketDialog(context, mainTicket),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text('Voir le ticket principal'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats secondaires - CLIQUABLES
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: orders > 0 ? () {
                    final cancellationEvents = List<Map<String, dynamic>>.from(serviceData['cancellationEvents'] ?? []);
                    _showFullScreenOrders(context, mergedOrderEvents, cancellationEvents);
                  } : null,
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStatItem('Commandes', orders.toString(), Icons.restaurant_menu, orders > 0),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: subNotes > 0 ? () => _showFullScreenSubNotes(context, sessions) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStatItem('Sous-notes', subNotes.toString(), Icons.note_add, subNotes > 0),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: payments > 0 ? () => _showFullScreenPayments(context, groupedPayments) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStatItem('Paiements', payments.toString(), Icons.payment, payments > 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isClickable) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isClickable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: isClickable ? Border.all(color: Colors.blue.shade200) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              if (isClickable) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blue.shade700),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showFullScreenOrders(BuildContext context, List<Map<String, dynamic>> orders, List<Map<String, dynamic>> cancellations) {
    // 🆕 Mélanger les commandes et les annulations par ordre chronologique
    final allEvents = <Map<String, dynamic>>[];
    
    // Ajouter les commandes
    for (var order in orders) {
      allEvents.add({
        ...order,
        'eventType': 'order',
      });
    }
    
    // Ajouter les annulations
    for (var cancellation in cancellations) {
      allEvents.add({
        ...cancellation,
        'eventType': 'cancellation',
      });
    }
    
    // Trier par timestamp
    allEvents.sort((a, b) {
      final timeA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
      final timeB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
      return timeA.compareTo(timeB);
    });
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
          child: Column(
            children: [
              // En-tête fixe
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Toutes les Commandes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Liste des commandes et annulations
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allEvents.length,
                  itemBuilder: (context, index) {
                    final event = allEvents[index];
                    final eventType = event['eventType'] as String?;
                    
                    if (eventType == 'cancellation') {
                      return CancellationEventCard(event: event);
                    } else {
                      // Trouver l'index de la commande dans la liste originale
                      final orderIndex = orders.indexWhere((o) => 
                        o['timestamp'] == event['timestamp'] && 
                        o['orderId'] == event['orderId']
                      );
                      return OrderEventCard(
                        event: event, 
                        index: orderIndex >= 0 ? orderIndex : index
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenPayments(BuildContext context, List<Map<String, dynamic>> payments) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
          child: Column(
            children: [
              // En-tête fixe
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tous les Paiements',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Liste des paiements
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    return RealPaymentCard(payment: payments[index], index: index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenSubNotes(BuildContext context, List<Map<String, dynamic>> sessions) {
    // 🆕 Extraire toutes les sous-notes directement depuis les sessions
    // Les sous-notes ne sont plus supprimées, elles restent présentes avec paid: true
    List<Map<String, dynamic>> allSubNotes = [];
    for (final session in sessions) {
      final orderId = session['id'];
      final subNotes = session['subNotes'] as List? ?? [];
      
      // 🆕 Utiliser directement les sous-notes de la session
      // Elles sont toujours présentes, même après paiement (marquées paid: true)
      for (final subNote in subNotes) {
        final noteMap = Map<String, dynamic>.from(subNote as Map);
        
        // 🆕 Ajouter orderId et createdAt si manquants
        noteMap['orderId'] = orderId;
        if (!noteMap.containsKey('createdAt')) {
          noteMap['createdAt'] = subNote['createdAt'] as String? ?? session['createdAt'] as String? ?? '';
        }
        
        // 🆕 Calculer le total depuis les items (avec paidQuantity si disponible)
        double total = 0.0;
        final items = noteMap['items'] as List? ?? [];
        for (final item in items) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          total += quantity * price;
        }
        noteMap['total'] = total;
        
        // 🆕 CORRECTION : Ne pas ajouter les sous-notes vides (sans articles ou avec total = 0)
        // Cela évite d'afficher des sous-notes vides dans l'historique
        if (items.isNotEmpty && total > 0) {
          allSubNotes.add(noteMap);
        }
      }
    }
    
    // Trier par date de création (plus récent en premier)
    allSubNotes.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['createdAt'] as String? ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
          child: Column(
            children: [
              // En-tête fixe
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Toutes les Sous-notes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Liste des sous-notes
              Expanded(
                child: allSubNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_add, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune sous-note',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: allSubNotes.length,
                        itemBuilder: (context, index) {
                          final subNote = allSubNotes[index];
                          final items = subNote['items'] as List? ?? [];
                          final name = subNote['name'] as String? ?? 'Sous-note';
                          final createdAt = subNote['createdAt'] as String? ?? '';
                          final time = HistoryService.formatDate(createdAt);
                          
                          // Calculer le total depuis les items (les sous-notes sont directement dans les sessions)
                          double total = (subNote['total'] as num?)?.toDouble() ?? 0.0;
                          if (total == 0.0 && items.isNotEmpty) {
                            for (final item in items) {
                              total += ((item['quantity'] as num?)?.toInt() ?? 0) * ((item['price'] as num?)?.toDouble() ?? 0.0);
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200, width: 1),
                                        ),
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  ...(items.map<Widget>((item) {
                                    final itemName = item['name'] as String? ?? 'N/A';
                                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                                    final itemTotal = quantity * price;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$quantity x $itemName',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Text(
                                            '${itemTotal.toStringAsFixed(2)} TND',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(2)} TND',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMainTicketDialog(BuildContext context, Map<String, dynamic> mainTicket) {
    final subtotal = (mainTicket['subtotal'] as num?)?.toDouble();
    final total = (mainTicket['total'] as num?)?.toDouble() ?? 0.0;
    final hasDiscount = mainTicket['hasDiscount'] == true;
    final discount = (mainTicket['discount'] as num?)?.toDouble() ?? 0.0;
    final isPercentDiscount = mainTicket['isPercentDiscount'] == true;
    final discountAmount = (mainTicket['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final List<Map<String, dynamic>> discountDetails =
        List<Map<String, dynamic>>.from(mainTicket['discountDetails'] as List? ?? []);
    final hasMultipleDiscountRates =
        mainTicket['hasMultipleDiscountRates'] == true || discountDetails.length > 1; // 🆕 Plusieurs taux différents
    final String singleDiscountLabel = discountDetails.isNotEmpty
        ? 'Remise ${discountDetails.first['rate']}:'
        : 'Remise ${discount.toStringAsFixed(0)}${isPercentDiscount ? '%' : ' TND'}:';
    final server = mainTicket['server'] as String?; // 🆕 Serveur qui a géré ce service
    final table = mainTicket['table']; // 🆕 Table pour traçabilité
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Ticket Principal'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête style ticket de caisse
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LES EMIRS RESTAURANT',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ticket Principal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      // 🆕 Afficher le serveur si disponible
                      if (server != null && server != 'unknown') ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Serveur: $server',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(),
                      
                      // Articles
                      if (mainTicket['items'] != null) ...[
                        ...(mainTicket['items'] as List? ?? []).map<Widget>((item) {
                          final itemTotal = (item['price'] as num? ?? 0.0).toDouble() * 
                                           ((item['quantity'] as num? ?? 0).toInt());
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['quantity']}x ${item['name']}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${itemTotal.toStringAsFixed(2)} TND',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                        
                        // 🆕 Affichage des remises si appliquées
                        if (hasDiscount && subtotal != null && subtotal > 0 && discountAmount > 0.01) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sous-total:',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${subtotal.toStringAsFixed(2)} TND',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 🆕 Afficher "Remises" si plusieurs taux, sinon le taux spécifique
                              Text(
                                hasMultipleDiscountRates
                                    ? 'Remises appliquées:'
                                    : singleDiscountLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '-${discountAmount.toStringAsFixed(2)} TND',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // 🆕 Afficher les détails des remises si plusieurs taux différents
                          if (discountDetails.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...discountDetails.map<Widget>((detail) {
                              final rate = detail['rate'] as String? ?? '';
                              final amount = (detail['amount'] as num?)?.toDouble() ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '  • Remise $rate:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '-${amount.toStringAsFixed(2)} TND',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 8),
                          const Divider(),
                        ],
                        
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              '${total.toStringAsFixed(2)} TND',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Merci de votre visite !',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// Carte pour un événement de commande individuel (affichage style ticket de caisse)
class OrderEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final int index;

  const OrderEventCard({
    super.key,
    required this.event,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = event['timestamp'] as String? ?? '';
    final items = event['items'] as List? ?? [];
    final time = HistoryService.formatDate(timestamp);
    
    // 🆕 Calculer le total de cette commande (EXCLURE les articles annulés)
    double commandTotal = 0.0;
    int cancelledItemsCount = 0;
    for (final item in items) {
      final isCancelled = item['cancelled'] == true;
      if (!isCancelled) {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        commandTotal += quantity * price;
      } else {
        cancelledItemsCount++;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : Commande #X - Heure
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // 🆕 CORRECTION : Afficher le vrai orderId au lieu de l'index pour séparer les commandes
                  'Commande #${event['orderId'] ?? (index + 1)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Articles - Style ticket de caisse
            if (items.isEmpty)
              Text(
                'Aucun article dans cette commande',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              ...(items.map<Widget>((item) {
                final itemName = item['name'] as String? ?? 'N/A';
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final itemTotal = quantity * price;
                final isCancelled = item['cancelled'] == true; // 🆕 Détecter si l'article est annulé
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // 🆕 Texte barré et grisé si annulé
                            Expanded(
                              child: Text(
                                '$quantity x $itemName',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  color: isCancelled ? Colors.grey.shade500 : Colors.black87,
                                  fontStyle: isCancelled ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            // 🆕 Badge "Annulé" si l'article est annulé
                            if (isCancelled)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade300, width: 1),
                                ),
                                child: Text(
                                  'Annulé',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${itemTotal.toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? Colors.grey.shade400 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              })),
              const Divider(height: 20),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${commandTotal.toStringAsFixed(2)} TND',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte pour un paiement réel (ticket encaissé)
class RealPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final int index;

  const RealPaymentCard({
    super.key,
    required this.payment,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = payment['timestamp'] as String? ?? '';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMode = payment['paymentMode'] as String? ?? 'N/A';
    final items = payment['items'] as List? ?? [];
    final orderIds = payment['orderIds'] as List? ?? [];
    final server = payment['server'] as String?; // 🆕 Serveur qui a géré ce paiement
    final table = payment['table']; // 🆕 Table pour traçabilité
    final time = HistoryService.formatDate(timestamp);
    
    // 🆕 Utiliser discountAmount directement (calculé à la source)
    final paymentDiscountAmount = (payment['discountAmount'] as num?)?.toDouble();
    final calculatedDiscount = paymentDiscountAmount ?? 
      ((payment['subtotal'] as num?)?.toDouble() ?? 0.0) - amount; // Rétrocompatibilité
    
    // 🆕 Détecter le type de paiement pour un meilleur affichage
    // Utiliser les flags du serveur si disponibles, sinon détecter depuis les données
    final noteId = payment['noteId'] as String?;
    final noteName = payment['noteName'] as String?;
    final isSubNote = payment['isSubNote'] == true || (noteId != null && noteId.startsWith('sub_'));
    final isMainNote = payment['isMainNote'] == true || noteId == 'main' || noteId == null;
    final isPartial = payment['isPartial'] == true;
    
    // 🆕 Détecter si c'est un paiement divisé
    final isSplitPayment = payment['isSplitPayment'] == true;
    final splitPaymentModes = (payment['splitPaymentModes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final splitPaymentAmounts = (payment['splitPaymentAmounts'] as List?)?.map((e) {
      if (e is Map) {
        return {
          'mode': e['mode']?.toString() ?? '', 
          'amount': (e['amount'] as num?)?.toDouble() ?? 0.0,
          'clientName': e['clientName']?.toString(), // 🆕 Nom du client pour CREDIT
        };
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList() ?? [];
    
    // 🆕 Nom du client CREDIT pour paiements non divisés
    final creditClientName = payment['creditClientName'] as String?;
    
    // 🆕 Titre selon le type de paiement
    String paymentTitle;
    IconData paymentTypeIcon;
    Color paymentTypeColor;
    
    if (isSubNote && noteName != null) {
      paymentTitle = 'Sous-note: $noteName';
      paymentTypeIcon = Icons.person;
      paymentTypeColor = Colors.purple.shade700;
    } else if (isPartial && isMainNote) {
      paymentTitle = 'Paiement partiel - Note principale';
      paymentTypeIcon = Icons.payment;
      paymentTypeColor = Colors.orange.shade700;
    } else if (isMainNote) {
      // 🆕 Si c'est un paiement complet, afficher "Note principale" au lieu de "Paiement partiel"
      paymentTitle = 'Note principale';
      paymentTypeIcon = Icons.receipt;
      paymentTypeColor = Colors.blue.shade700;
    } else {
      paymentTitle = 'Ticket #${index + 1}';
      paymentTypeIcon = Icons.receipt;
      paymentTypeColor = Colors.grey.shade700;
    }

    // Couleur selon le mode de paiement
    Color modeColor;
    IconData modeIcon;
    switch (paymentMode.toUpperCase()) {
      case 'ESPECE':
        modeColor = Colors.green.shade700;
        modeIcon = Icons.money;
        break;
      case 'CARTE':
        modeColor = Colors.blue.shade700;
        modeIcon = Icons.credit_card;
        break;
      case 'CHEQUE':
        modeColor = Colors.purple.shade700;
        modeIcon = Icons.receipt;
        break;
      case 'TPE':
        modeColor = Colors.orange.shade700;
        modeIcon = Icons.payment;
        break;
      case 'OFFRE':
        modeColor = Colors.red.shade700;
        modeIcon = Icons.card_giftcard;
        break;
      case 'CREDIT':
        modeColor = Colors.orange.shade700;
        modeIcon = Icons.account_balance_wallet;
        break;
      default:
        modeColor = Colors.grey.shade700;
        modeIcon = Icons.receipt;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête simple
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: modeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(modeIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🆕 Titre avec type de paiement
                      Row(
                        children: [
                          Icon(
                            paymentTypeIcon,
                            size: 16,
                            color: paymentTypeColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              paymentTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: paymentTypeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200, width: 1),
                        ),
                        child: Text(
                          time,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      // 🆕 Afficher le serveur si disponible
                      if (server != null && server != 'unknown') ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Serveur: $server',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${amount.toStringAsFixed(2)} TND',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: modeColor,
                      ),
                    ),
                    // 🆕 Afficher l'indication du pourboire si présent
                    Builder(
                      builder: (context) {
                        final excessAmount = (payment['excessAmount'] as num?)?.toDouble();
                        if (excessAmount != null && excessAmount > 0.01) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Inclut pourboire: ${excessAmount.toStringAsFixed(2)} TND',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Badges simples
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 🆕 Badge "Paiement divisé" si applicable
                if (isSplitPayment)
                  Chip(
                    avatar: Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue.shade700),
                    label: Text(
                      'Paiement divisé',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    backgroundColor: Colors.blue.shade50,
                  ),
                // 🆕 Badge type de paiement
                Chip(
                  avatar: Icon(paymentTypeIcon, size: 16, color: paymentTypeColor),
                  label: Text(
                    isSubNote ? noteName ?? 'Sous-note' : (isPartial ? 'Partiel' : 'Complet'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: paymentTypeColor,
                    ),
                  ),
                  backgroundColor: paymentTypeColor.withOpacity(0.1),
                ),
                // Badge mode(s) de paiement
                if (isSplitPayment && splitPaymentModes.isNotEmpty)
                  // 🆕 Afficher tous les modes pour paiement divisé
                  ...splitPaymentModes.map((mode) {
                    Color modeColor;
                    IconData modeIcon;
                    switch (mode.toUpperCase()) {
                      case 'ESPECE':
                        modeColor = Colors.green.shade700;
                        modeIcon = Icons.money;
                        break;
                      case 'CARTE':
                        modeColor = Colors.blue.shade700;
                        modeIcon = Icons.credit_card;
                        break;
                      case 'CHEQUE':
                        modeColor = Colors.purple.shade700;
                        modeIcon = Icons.receipt;
                        break;
                      case 'TPE':
                        modeColor = Colors.orange.shade700;
                        modeIcon = Icons.payment;
                        break;
                      case 'OFFRE':
                        modeColor = Colors.red.shade700;
                        modeIcon = Icons.card_giftcard;
                        break;
                      case 'CREDIT':
                        modeColor = Colors.orange.shade700;
                        modeIcon = Icons.account_balance_wallet;
                        break;
                      default:
                        modeColor = Colors.grey.shade700;
                        modeIcon = Icons.receipt;
                    }
                    
                    // 🆕 Filtrer tous les montants de ce mode (peut y en avoir plusieurs avec index)
                    final modeAmounts = splitPaymentAmounts.where((e) => e['mode'] == mode).toList();
                    
                    // 🆕 Si plusieurs montants, afficher tous avec leurs numéros (1, 2, 3...)
                    if (modeAmounts.length > 1) {
                      // Afficher tous les montants avec leurs indices
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: modeAmounts.asMap().entries.map((entry) {
                          final displayIndex = entry.key + 1; // Index d'affichage (1, 2, 3...)
                          final amountData = entry.value;
                          final splitAmount = (amountData['amount'] as num?)?.toDouble() ?? 0.0;
                          final clientName = amountData['clientName'] as String?;
                          
                          // 🆕 Construire le label avec le numéro et le nom du client si CREDIT
                          String labelText;
                          if (mode.toUpperCase() == 'CREDIT' && clientName != null && clientName.isNotEmpty) {
                            labelText = '$mode #$displayIndex ($clientName) - ${splitAmount.toStringAsFixed(2)} TND';
                          } else {
                            labelText = '$mode #$displayIndex - ${splitAmount.toStringAsFixed(2)} TND';
                          }
                          
                          return Chip(
                            avatar: Icon(modeIcon, size: 16, color: modeColor),
                            label: Text(
                              labelText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: modeColor,
                              ),
                            ),
                            backgroundColor: modeColor.withOpacity(0.1),
                          );
                        }).toList(),
                      );
                    } else {
                      // Un seul montant, affichage normal
                      final splitAmountData = modeAmounts.isNotEmpty ? modeAmounts[0] : {'amount': 0.0, 'clientName': null};
                      final splitAmount = (splitAmountData['amount'] as num?)?.toDouble() ?? 0.0;
                      final clientName = splitAmountData['clientName'] as String?;
                      
                      // 🆕 Construire le label avec le nom du client si CREDIT
                      String labelText;
                      if (mode.toUpperCase() == 'CREDIT' && clientName != null && clientName.isNotEmpty) {
                        labelText = '$mode ($clientName) - ${splitAmount.toStringAsFixed(2)} TND';
                      } else {
                        labelText = '$mode (${splitAmount.toStringAsFixed(2)} TND)';
                      }
                      
                      return Chip(
                        avatar: Icon(modeIcon, size: 16, color: modeColor),
                        label: Text(
                          labelText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: modeColor,
                          ),
                        ),
                        backgroundColor: modeColor.withOpacity(0.1),
                      );
                    }
                  }).toList()
                else
                  // Badge mode de paiement unique
                  Chip(
                    avatar: Icon(modeIcon, size: 16, color: modeColor),
                    label: Text(
                      // 🆕 Afficher le nom du client si CREDIT
                      paymentMode.toUpperCase() == 'CREDIT' && creditClientName != null && creditClientName.isNotEmpty
                          ? '$paymentMode ($creditClientName)'
                          : paymentMode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: modeColor,
                      ),
                    ),
                    backgroundColor: modeColor.withOpacity(0.1),
                  ),
                if (payment['hasDiscount'] == true && payment['discount'] != null && (payment['discount'] as num) > 0)
                  Chip(
                    avatar: Icon(Icons.local_offer, size: 16, color: Colors.orange.shade700),
                    label: Text(
                      'Remise: ${(payment['discount'] as num).toStringAsFixed(0)}${payment['isPercentDiscount'] == true ? '%' : ' TND'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    backgroundColor: Colors.orange.shade50,
                  ),
              ],
            ),
            
            // Articles payés - SIMPLE
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...(items.map<Widget>((item) {
                final itemTotal = (item['total'] as num?)?.toDouble() ?? 
                    ((item['price'] as num?)?.toDouble() ?? 0.0) * 
                    ((item['quantity'] as num?)?.toInt() ?? 0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['quantity']}x ${item['name']}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${itemTotal.toStringAsFixed(2)} TND',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              })),
              const Divider(height: 20),
              // Total avec remise si applicable
              // 🆕 Utiliser discountAmount directement (calculé à la source)
              if (payment['hasDiscount'] == true && (payment['subtotal'] != null || paymentDiscountAmount != null)) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sous-total', style: TextStyle(fontSize: 13)),
                    Text('${((payment['subtotal'] as num?)?.toDouble() ?? amount).toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remise ${((payment['discount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}${payment['isPercentDiscount'] == true ? '%' : ' TND'}',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                    Text(
                      '-${calculatedDiscount.toStringAsFixed(2)} TND',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                    ),
                  ],
                ),
                const Divider(height: 20),
              ],
              // Total final
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: modeColor,
                        ),
                      ),
                      Text(
                        '${amount.toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: modeColor,
                        ),
                      ),
                    ],
                  ),
                  // 🆕 Afficher l'indication du pourboire si présent
                  Builder(
                    builder: (context) {
                      final excessAmount = (payment['excessAmount'] as num?)?.toDouble();
                      if (excessAmount != null && excessAmount > 0.01) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Inclut pourboire: ${excessAmount.toStringAsFixed(2)} TND',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 🆕 Carte pour un événement d'annulation (affichage détaillé)
class CancellationEventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const CancellationEventCard({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = event['timestamp'] as String? ?? '';
    final items = event['items'] as List? ?? [];
    final time = HistoryService.formatDate(timestamp);
    final cancellationDetails = event['cancellationDetails'] as Map<String, dynamic>? ?? {};
    final state = cancellationDetails['state'] as String? ?? 'not_prepared';
    final reason = cancellationDetails['reason'] as String? ?? 'other';
    final action = cancellationDetails['action'] as String? ?? 'cancel';
    final description = cancellationDetails['description'] as String? ?? '';
    final noteName = event['noteName'] as String? ?? 'Note Principale';
    
    // Labels
    final stateLabels = {
      'not_prepared': 'Non préparé',
      'prepared_not_served': 'Préparé non servi',
      'served_untouched': 'Servi non entamé',
      'served_touched': 'Servi entamé',
    };
    final reasonLabels = {
      'non_conformity': 'Non-conformité',
      'quality': 'Qualité/Goût',
      'delay': 'Délai',
      'order_error': 'Erreur commande',
      'client_dissatisfied': 'Client insatisfait',
      'other': 'Autre',
    };
    final actionLabels = {
      'cancel': 'Annulation',
      'refund': 'Remboursement',
      'replace': 'Remplacement',
      'remake': 'Refaire',
      'reassign': 'Réaffectation',
    };
    
    // Calculer le total des articles annulés
    double cancelledTotal = 0.0;
    for (final item in items) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      cancelledTotal += quantity * price;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : Annulation - Heure
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Annulation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            if (noteName != 'Note Principale') ...[
              const SizedBox(height: 4),
              Text(
                'Note: $noteName',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const Divider(height: 20),
            
            // Articles annulés
            if (items.isEmpty)
              Text(
                'Aucun article annulé',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              ...(items.map<Widget>((item) {
                final itemName = item['name'] as String? ?? 'N/A';
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final itemTotal = quantity * price;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$quantity x $itemName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${itemTotal.toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              })),
              const Divider(height: 20),
              // Total annulé
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL ANNULÉ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    '${cancelledTotal.toStringAsFixed(2)} TND',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Détails de l'annulation
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      stateLabels[state] ?? state,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                  ),
                  Chip(
                    label: Text(
                      reasonLabels[reason] ?? reason,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                  ),
                  Chip(
                    label: Text(
                      actionLabels[action] ?? action,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

