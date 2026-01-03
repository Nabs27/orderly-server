import 'package:flutter/material.dart';

class TableCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final bool isTablet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color Function(String status) getTableColor;
  final Color Function(dynamic lastOrderAt) getInactivityColor;
  final String Function(DateTime? openedAt) getElapsedTime;
  final String Function(dynamic lastOrderAt) getTimeSinceLastOrder;

  const TableCard({
    super.key,
    required this.table,
    required this.isTablet,
    required this.onTap,
    required this.onLongPress,
    required this.getTableColor,
    required this.getInactivityColor,
    required this.getElapsedTime,
    required this.getTimeSinceLastOrder,
  });

  @override
  Widget build(BuildContext context) {
    final status = table['status'] as String;
    final number = table['number'] as String;
    final covers = table['covers'] as int;
    final openedAt = table['openedAt'] is String
        ? DateTime.tryParse(table['openedAt'] as String)
        : table['openedAt'] as DateTime?;
    final elapsedTime = getElapsedTime(openedAt);
    final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
    final hasOrder = orderTotal > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: getTableColor(status),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'occupee' ? Colors.orange : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRect(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 8.0 : 6.0),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🆕 Badge avec nombre de tickets si > 1
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Table N° $number',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // 🆕 Badge nombre de tickets
                      if ((table['activeNotesCount'] as int? ?? 0) > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: isTablet ? 28 : 24,
                          height: isTablet ? 28 : 24,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${table['activeNotesCount']}',
                              style: TextStyle(
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (covers > 0) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 10 : 6,
                        vertical: isTablet ? 4 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$covers couverts',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                  if (openedAt != null) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 5 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: isTablet ? 14 : 12,
                          ),
                          SizedBox(width: isTablet ? 6 : 4),
                          Text(
                            elapsedTime,
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // 🆕 Badge nouvelle commande client (vert, pour distinguer des anciennes)
                  if ((table['hasNewClientOrder'] as bool? ?? false)) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: isTablet ? 2 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade300,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: isTablet ? 16 : 14,
                              ),
                              SizedBox(width: isTablet ? 6 : 4),
                              Flexible(
                                child: Text(
                                  'Nouvelle commande',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 🆕 Afficher le résumé des articles
                          if (table['newClientOrderItems'] != null && 
                              (table['newClientOrderItems'] as List).isNotEmpty) ...[
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatItemsSummary(table['newClientOrderItems'] as List),
                                style: TextStyle(
                                  fontSize: isTablet ? 10 : 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // 🆕 Badge commande client en attente de confirmation (orange, pour les anciennes)
                  if ((table['hasPendingClientOrders'] as bool? ?? false) && 
                      !(table['hasNewClientOrder'] as bool? ?? false)) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: isTablet ? 2 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.shade300,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pending_actions,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          ),
                          SizedBox(width: isTablet ? 6 : 4),
                          Flexible(
                            child: Text(
                              'En attente',
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasOrder) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 14 : 10,
                        vertical: isTablet ? 7 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: isTablet ? 2 : 1.5,
                        ),
                      ),
                      child: Text(
                        '${orderTotal.toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  if (table['lastOrderAt'] != null) ...[
                    SizedBox(height: isTablet ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 10 : 8,
                        vertical: isTablet ? 5 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: getInactivityColor(table['lastOrderAt']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: isTablet ? 6 : 4),
                          Text(
                            getTimeSinceLastOrder(table['lastOrderAt']),
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 1),
                  const Text(
                    'Appui long = Paiement',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 Helper pour formater le résumé des articles
  String _formatItemsSummary(List<dynamic> items) {
    final Map<String, int> itemCounts = {};
    for (final item in items) {
      final name = item['name'] as String? ?? 'Article';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      itemCounts[name] = (itemCounts[name] ?? 0) + qty;
    }
    
    final summary = itemCounts.entries
        .map((e) => '${e.value}x ${e.key}')
        .take(3) // Limiter à 3 articles pour ne pas surcharger
        .join(', ');
    
    return itemCounts.length > 3 ? '$summary...' : summary;
  }
}


