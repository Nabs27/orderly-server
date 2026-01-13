import 'package:flutter/material.dart';
import 'TableCard.dart';

class TableGrid extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final VoidCallback onAddTable;
  final void Function(Map<String, dynamic> table) onTapTable;
  final void Function(Map<String, dynamic> table) onLongPressTable;
  final Color Function(String status) getTableColor;
  final Color Function(dynamic lastOrderAt) getInactivityColor;
  final String Function(DateTime? openedAt) getElapsedTime;
  final String Function(dynamic lastOrderAt) getTimeSinceLastOrder;

  const TableGrid({
    super.key,
    required this.tables,
    required this.onAddTable,
    required this.onTapTable,
    required this.onLongPressTable,
    required this.getTableColor,
    required this.getInactivityColor,
    required this.getElapsedTime,
    required this.getTimeSinceLastOrder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final crossAxisCount = screenWidth > 1200 ? 6 : (screenWidth > 800 ? 5 : 4);
        final spacing = screenWidth > 1200 ? 20.0 : 16.0;
        final isTablet = screenWidth > 600;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: isTablet ? 1.3 : 1.1,
          ),
          itemCount: tables.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return InkWell(
                onTap: onAddTable,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade300,
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
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 40, color: Colors.blue.shade600),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter Table',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nouvelle table',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final table = tables[i - 1];
            return TableCard(
              table: table,
              isTablet: isTablet,
              onTap: () => onTapTable(table),
              onLongPress: () => onLongPressTable(table),
              getTableColor: getTableColor,
              getInactivityColor: getInactivityColor,
              getElapsedTime: getElapsedTime,
              getTimeSinceLastOrder: getTimeSinceLastOrder,
            );
          },
        );
      },
    );
  }
}


