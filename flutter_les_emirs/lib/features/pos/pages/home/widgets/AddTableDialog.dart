import 'package:flutter/material.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class AddTableDialog extends StatefulWidget {
  const AddTableDialog({super.key});
  @override
  State<AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<AddTableDialog> {
  final TextEditingController tableNumberController = TextEditingController();
  final FocusNode _tableNumberFocusNode = FocusNode();
  int covers = 1;

  @override
  void dispose() {
    _tableNumberFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          type: MaterialType.card,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre
                const Text(
                  'Ajouter une table',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Champ numéro de table
                VirtualKeyboardTextField(
                  controller: tableNumberController,
                  focusNode: _tableNumberFocusNode,
                  keyboardType: VirtualKeyboardType.numeric,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Numéro de table',
                    labelStyle: TextStyle(fontSize: 18),
                    hintText: 'Ex: 1, 2, 3...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.table_restaurant, size: 28),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nombre de couverts:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                        onPressed: covers > 1 ? () => setState(() => covers--) : null,
                        icon: const Icon(Icons.remove_circle, size: 40),
                        color: Colors.red.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        '$covers',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                        onPressed: () => setState(() => covers++),
                        icon: const Icon(Icons.add_circle, size: 40),
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 56,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                        child: const Text('Annuler', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final tableNumber = tableNumberController.text.trim();
                          if (tableNumber.isNotEmpty) {
                            Navigator.of(context).pop({'number': tableNumber, 'covers': covers});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Créer',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
