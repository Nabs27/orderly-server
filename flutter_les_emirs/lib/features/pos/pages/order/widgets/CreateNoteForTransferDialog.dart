import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class CreateNoteForTransferDialog extends StatelessWidget {
  final Map<int, int> selectedItems;
  final Function(String name, int covers, Map<int, int> selectedItems) onCreateNote;

  const CreateNoteForTransferDialog({
    super.key,
    required this.selectedItems,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final coversController = TextEditingController(text: '1');
    
    return AlertDialog(
      title: const Text('Créer une nouvelle note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VirtualKeyboardTextField(
            controller: nameController,
            keyboardType: VirtualKeyboardType.alpha,
            decoration: const InputDecoration(
              labelText: 'Nom du client',
              hintText: 'Ex: Ahmed, Sarah, etc.',
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final covers = int.tryParse(coversController.text) ?? 1;
            if (name.isNotEmpty) {
              Navigator.of(context).pop();
              onCreateNote(name, covers, selectedItems);
            }
          },
          child: const Text('Créer et transférer'),
        ),
      ],
    );
  }
}

