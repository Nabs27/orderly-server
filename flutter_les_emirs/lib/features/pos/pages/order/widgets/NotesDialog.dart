import 'package:flutter/material.dart';

class NotesDialog extends StatelessWidget {
  final String currentNotes;
  final Function(String) onNotesChanged;

  const NotesDialog({
    super.key,
    required this.currentNotes,
    required this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: currentNotes);
    
    return AlertDialog(
      title: const Text('Note / Remarque'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            onNotesChanged(controller.text);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

