import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class CoversDialog extends StatelessWidget {
  final int currentCovers;
  final Function(int) onCoversChanged;

  const CoversDialog({
    super.key,
    required this.currentCovers,
    required this.onCoversChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: currentCovers.toString());
    
    return AlertDialog(
      title: const Text('Nombre de couverts'),
      content: VirtualKeyboardTextField(
        controller: controller,
        keyboardType: VirtualKeyboardType.numeric,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Couverts', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final newCovers = int.tryParse(controller.text) ?? currentCovers;
            onCoversChanged(newCovers);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

