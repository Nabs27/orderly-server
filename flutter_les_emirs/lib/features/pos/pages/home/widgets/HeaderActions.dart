import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';

class HeaderActions extends StatelessWidget {
  final VoidCallback onSimulation;
  final VoidCallback onAdmin;

  const HeaderActions({
    super.key,
    required this.onSimulation,
    required this.onAdmin,
  });

  Future<void> _restartServices(BuildContext context) async {
    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redémarrer les services'),
        content: const Text(
          'Cette action va redémarrer le serveur Node.js et l\'application Flutter.\n\n'
          'Les fenêtres vont se fermer et se rouvrir automatiquement.\n\n'
          'Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.7),
            ),
            child: const Text('Redémarrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Redémarrage en cours...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Appeler l'endpoint de redémarrage
      final response = await ApiClient.dio.post(
        '/api/admin/restart-services',
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de chargement

        if (response.data['ok'] == true) {
          // 🆕 Afficher un dialog avec instructions pour fermer le navigateur
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  const Text('Redémarrage lancé'),
                ],
              ),
              content: const Text(
                'Le serveur et le POS sont en cours de redémarrage.\n\n'
                '⚠️ REDÉMARRAGE AUTOMATIQUE :\n'
                '1. Le serveur Node.js va redémarrer dans une nouvelle fenêtre "Serveur REST"\n'
                '2. L\'application Flutter va se fermer automatiquement\n'
                '3. Le POS Flutter va redémarrer dans une nouvelle fenêtre "POS Flutter"\n'
                '4. Attendez 10-15 secondes que les services redémarrent\n'
                '5. L\'application devrait se rouvrir automatiquement\n\n'
                'Note: Si l\'application ne se rouvre pas, relancez-la manuellement.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Afficher un message final
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('⚠️ FERMEZ MAINTENANT cette fenêtre du navigateur (Alt+F4)'),
                        backgroundColor: Colors.orange.withValues(alpha: 0.7),
                        duration: const Duration(seconds: 15),
                        action: SnackBarAction(
                          label: 'Compris',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  child: const Text('Compris'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors du redémarrage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2A37),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onSimulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Simulation'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAdmin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Admin'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _restartServices(context),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Redémarrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.7),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}


