import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class CreateTableForTransferDialog extends StatelessWidget {
  final Map<int, int> selectedItems;
  final Function(String tableNumber, int covers, String? clientName, Map<int, int> selectedItems) onCreateTable;

  const CreateTableForTransferDialog({
    super.key,
    required this.selectedItems,
    required this.onCreateTable,
  });

  @override
  Widget build(BuildContext context) {
    final tableController = TextEditingController();
    final coversController = TextEditingController(text: '1');
    final nameController = TextEditingController();
    
    return AlertDialog(
      title: const Text('Créer une nouvelle table'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VirtualKeyboardTextField(
            controller: tableController,
            keyboardType: VirtualKeyboardType.numeric,
            decoration: const InputDecoration(
              labelText: 'Numéro de table',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          VirtualKeyboardTextField(
            controller: coversController,
            keyboardType: VirtualKeyboardType.numeric,
            decoration: const InputDecoration(
              labelText: 'Nombre de couverts',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          VirtualKeyboardTextField(
            controller: nameController,
            keyboardType: VirtualKeyboardType.alpha,
            decoration: const InputDecoration(
              labelText: 'Nom du client (optionnel)',
              hintText: 'Ex: Ahmed, Sarah, etc.',
              border: OutlineInputBorder(),
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
            final clientName = nameController.text.trim();
            if (tableNumber.isNotEmpty) {
              Navigator.of(context).pop();
              onCreateTable(tableNumber, covers, clientName.isEmpty ? null : clientName, selectedItems);
            }
          },
          child: const Text('Créer et transférer'),
        ),
      ],
    );
  }
}

