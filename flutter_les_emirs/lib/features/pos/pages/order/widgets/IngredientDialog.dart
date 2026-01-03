import 'package:flutter/material.dart';

class IngredientDialog extends StatelessWidget {
  final String itemName;
  final Function(String)? onIngredientChanged;

  const IngredientDialog({
    super.key,
    required this.itemName,
    this.onIngredientChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    
    return AlertDialog(
      title: Text('Modifier: $itemName'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Ingrédients / Modifications',
          hintText: 'Ex: Sans sauce, sans oignons',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (onIngredientChanged != null) {
              onIngredientChanged!(controller.text);
            }
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

