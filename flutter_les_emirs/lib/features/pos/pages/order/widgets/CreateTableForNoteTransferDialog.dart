import 'package:flutter/material.dart';

class CreateTableForNoteTransferDialog extends StatelessWidget {
  final String noteName;
  final Map<int, int> selectedItems;
  final Function(String tableNumber, int covers, Map<int, int> selectedItems) onCreateTable;

  const CreateTableForNoteTransferDialog({
    super.key,
    required this.noteName,
    required this.selectedItems,
    required this.onCreateTable,
  });

  @override
  Widget build(BuildContext context) {
    final tableController = TextEditingController();
    final coversController = TextEditingController(text: '1');
    
    return AlertDialog(
      title: Text('Créer table pour $noteName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.purple.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$noteName aura sa propre table avec ses articles',
                    style: TextStyle(color: Colors.purple.withValues(alpha: 0.7), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: tableController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Numéro de table',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.table_restaurant),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: coversController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nombre de couverts',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.people),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final tableNumber = tableController.text.trim();
            final covers = int.tryParse(coversController.text) ?? 1;
            if (tableNumber.isNotEmpty) {
              Navigator.of(context).pop();
              onCreateTable(tableNumber, covers, selectedItems);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('Créer table', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

