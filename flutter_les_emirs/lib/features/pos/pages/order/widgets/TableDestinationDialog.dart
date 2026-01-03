import 'package:flutter/material.dart';
import '../../../models/order_note.dart';

class TableDestinationDialog extends StatelessWidget {
  final Map<int, int> selectedItems;
  final String currentTableNumber;
  final String activeNoteId;
  final OrderNote activeNote;
  final Future<List<Map<String, dynamic>>> Function() getAvailableTables;
  final Function(String tableNumber, Map<int, int> items, bool createTable) onTransferToTable;
  final Function(Map<int, int>) onCreateTableForTransfer;
  final Function(Map<int, int>) onCreateTableForNoteTransfer;

  const TableDestinationDialog({
    super.key,
    required this.selectedItems,
    required this.currentTableNumber,
    required this.activeNoteId,
    required this.activeNote,
    required this.getAvailableTables,
    required this.onTransferToTable,
    required this.onCreateTableForTransfer,
    required this.onCreateTableForNoteTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getAvailableTables(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AlertDialog(
            title: const Text('Chargement...'),
            content: const Center(child: CircularProgressIndicator()),
          );
        }

        final availableTables = snapshot.data ?? [];
        
        return AlertDialog(
          title: const Text('Vers quelle table ?'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              children: [
                const Text('Choisissez la table de destination :'),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: availableTables.length,
                    itemBuilder: (_, i) {
                      final table = availableTables[i];
                      final tableNumber = table['number'] as String;
                      final covers = table['covers'] as int? ?? 1;
                      final total = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
                      
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.table_restaurant, color: Colors.blue),
                          title: Text('Table $tableNumber'),
                          subtitle: Text('${covers} couvert${covers > 1 ? 's' : ''} - ${total.toStringAsFixed(2)} TND'),
                          onTap: () {
                            Navigator.of(context).pop();
                            onTransferToTable(tableNumber, selectedItems, false);
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                const Divider(),
                
                Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.green),
                    title: const Text('Créer une nouvelle table'),
                    subtitle: const Text('Nouvelle table avec ces articles'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onCreateTableForTransfer(selectedItems);
                    },
                  ),
                ),
                
                if (activeNoteId != 'main')
                  Card(
                    color: Colors.purple.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.table_restaurant, color: Colors.purple),
                      title: Text('Créer table pour ${activeNote.name}'),
                      subtitle: const Text('Nouvelle table avec note séparée'),
                      onTap: () {
                        Navigator.of(context).pop();
                        onCreateTableForNoteTransfer(selectedItems);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }
}

