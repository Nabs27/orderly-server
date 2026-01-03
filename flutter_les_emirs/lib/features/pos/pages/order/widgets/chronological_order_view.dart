import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/order_note.dart';

/// Widget pour afficher les commandes dans l'ordre chronologique
class ChronologicalOrderView extends StatelessWidget {
  final List<Map<String, dynamic>> rawOrders;
  final String activeNoteId;
  final int? selectedLineIndex;
  final Function(int) onItemSelected;

  const ChronologicalOrderView({
    super.key,
    required this.rawOrders,
    required this.activeNoteId,
    this.selectedLineIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (rawOrders.isEmpty) {
      return const Center(
        child: Text('Aucune commande', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    // Trier les commandes par date de création (plus récentes en premier)
    final sortedOrders = List<Map<String, dynamic>>.from(rawOrders);
    sortedOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['createdAt'] as String? ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // Plus récent en premier
    });

    return ListView.builder(
      itemCount: sortedOrders.length,
      itemBuilder: (context, orderIndex) {
        final order = sortedOrders[orderIndex];
        final orderId = order['id'] as int?;
        final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
        final server = order['server'] as String? ?? 'N/A';
        
        // Déterminer les articles à afficher selon la note active
        List<Map<String, dynamic>> itemsToShow = [];
        
        if (activeNoteId == 'main') {
          // Afficher les articles de la note principale
          final mainNote = order['mainNote'] as Map<String, dynamic>?;
          if (mainNote != null) {
            final mainItems = (mainNote['items'] as List?) ?? [];
            for (final itemData in mainItems) {
              final item = itemData as Map<String, dynamic>;
              final totalQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
              final paidQuantity = (item['paidQuantity'] as num?)?.toInt() ?? 0;
              final unpaidQuantity = totalQuantity - paidQuantity;
              
              if (unpaidQuantity > 0) {
                itemsToShow.add({
                  ...item,
                  'quantity': unpaidQuantity,
                  'sourceNoteId': 'main',
                });
              }
            }
          }
        } else {
          // Afficher les articles de la sous-note active
          final subNotes = (order['subNotes'] as List?) ?? [];
          for (final subNoteData in subNotes) {
            final subNote = subNoteData as Map<String, dynamic>;
            if (subNote['id'] == activeNoteId) {
              final subItems = (subNote['items'] as List?) ?? [];
              for (final itemData in subItems) {
                final item = itemData as Map<String, dynamic>;
                final totalQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final paidQuantity = (item['paidQuantity'] as num?)?.toInt() ?? 0;
                final unpaidQuantity = totalQuantity - paidQuantity;
                
                if (unpaidQuantity > 0) {
                  itemsToShow.add({
                    ...item,
                    'quantity': unpaidQuantity,
                    'sourceNoteId': activeNoteId,
                  });
                }
              }
              break;
            }
          }
        }

        // Ne pas afficher les commandes sans articles pour la note active
        if (itemsToShow.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildOrderCard(
          context,
          order: order, // 🆕 Passer l'ordre complet pour vérifier originalSource
          orderId: orderId,
          createdAt: createdAt,
          server: server,
          items: itemsToShow,
          orderIndex: orderIndex,
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context, {
    required Map<String, dynamic> order, // 🆕 Ordre complet pour vérifier originalSource
    required int? orderId,
    required DateTime? createdAt,
    required String server,
    required List<Map<String, dynamic>> items,
    required int orderIndex,
  }) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    // 🆕 Vérifier si c'est une commande client (via originalSource)
    final isClientOrder = order['originalSource'] == 'client';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8, top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la commande
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  createdAt != null
                      ? '${dateFormat.format(createdAt)} ${timeFormat.format(createdAt)}'
                      : 'Date inconnue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  isClientOrder 
                    ? 'Cmd #$orderId client'  // 🆕 Afficher "client" pour traçabilité
                    : 'Cmd #$orderId',
                  style: TextStyle(
                    fontSize: 11,
                    color: isClientOrder 
                      ? Colors.orange.shade700  // 🆕 Couleur discrète pour distinction
                      : Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  server,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Articles de la commande
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final itemName = item['name'] as String? ?? 'N/A';
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final amount = price * quantity;
            
            return InkWell(
              onTap: () => onItemSelected(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        itemName,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        price.toStringAsFixed(3),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        amount.toStringAsFixed(3),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

