import 'package:flutter/material.dart';

class SimulationDialog extends StatelessWidget {
  final void Function(String mode) onRun;
  final VoidCallback onReset;
  const SimulationDialog({super.key, required this.onRun, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simulation de Données'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Générer des données réalistes pour tester le système :'),
          SizedBox(height: 16),
          Text('• 3 serveurs (MOHAMED, ALI, FATMA)'),
          Text('• 30 tables au total (10 par serveur)'),
          Text('• Commandes sur 5h d\'ouverture'),
          Text('• Sous-notes avec noms de clients'),
          Text('• Articles du menu réel'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onRun('once');
          },
          icon: const Icon(Icons.flash_on),
          label: const Text('En une fois'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onRun('progressive');
          },
          icon: const Icon(Icons.timeline),
          label: const Text('Progressive'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onReset();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Remettre à zéro'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
