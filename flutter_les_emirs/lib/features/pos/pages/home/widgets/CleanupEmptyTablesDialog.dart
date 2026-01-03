import 'package:flutter/material.dart';

class CleanupEmptyTablesDialog extends StatelessWidget {
  final List<Map<String, dynamic>> emptyTables;
  const CleanupEmptyTablesDialog({super.key, required this.emptyTables});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nettoyer les tables vides'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tables sans commande trouvées: ${emptyTables.length}'),
          if (emptyTables.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Tables à supprimer:'),
            const SizedBox(height: 4),
            ...emptyTables.map((t) => Text('• Table N° ${t['number']}')),
          ] else ...[
            const SizedBox(height: 8),
            const Text('Aucune table vide à nettoyer.'),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        if (emptyTables.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Nettoyer'),
          ),
      ],
    );
  }
}


