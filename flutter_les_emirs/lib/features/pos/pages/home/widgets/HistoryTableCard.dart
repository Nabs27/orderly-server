import 'package:flutter/material.dart';
import '../services/history_service.dart';

/// Carte pour afficher une table dans l'historique
class HistoryTableCard extends StatelessWidget {
  final String tableNumber;
  final List<Map<String, dynamic>> sessions;
  final int sessionCount;
  final Map<String, dynamic>? tableData; // 🆕 Données pré-traitées pour accéder aux stats
  final VoidCallback onTap;

  const HistoryTableCard({
    super.key,
    required this.tableNumber,
    required this.sessions,
    required this.sessionCount,
    this.tableData, // 🆕 Optionnel pour compatibilité
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Calculer le total depuis les paiements réels (avec remises)
    double totalAmount = 0.0;
    
    // Utiliser stats.totalAmount depuis chaque service si disponible
    if (tableData != null) {
      final services = tableData!['services'] as Map<String, dynamic>? ?? {};
      for (final serviceEntry in services.values) {
        final serviceData = serviceEntry as Map<String, dynamic>? ?? {};
        final stats = serviceData['stats'] as Map<String, dynamic>? ?? {};
        final serviceTotal = (stats['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalAmount += serviceTotal;
      }
    } else {
      // Fallback : calculer depuis paymentHistory si disponible
      for (final session in sessions) {
        final paymentHistory = session['paymentHistory'] as List? ?? [];
        if (paymentHistory.isNotEmpty) {
          for (final payment in paymentHistory) {
            totalAmount += (payment['amount'] as num?)?.toDouble() ?? 0.0;
          }
        } else {
          // Fallback final : calculer depuis les items
          totalAmount += HistoryService.calculateSessionTotal(session);
        }
      }
    }

    // Date de la session la plus récente (parmi les sessions filtrées)
    String latestDate = '';
    if (sessions.isNotEmpty) {
    final latestSession = sessions.first;
      latestDate = HistoryService.formatDate(
      latestSession['archivedAt'] ?? latestSession['createdAt'],
    );
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge nombre de sessions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sessionCount ${sessionCount > 1 ? 'services' : 'service'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Numéro de table
              Text(
                'Table $tableNumber',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 6),
              // Date dernière session - 🆕 Taille augmentée pour meilleure lisibilité
              Text(
                latestDate,
                style: TextStyle(
                  fontSize: 14, // 🆕 Augmenté de 12 à 14
                  fontWeight: FontWeight.w500, // 🆕 Ajout de poids pour meilleure visibilité
                  color: Colors.grey.withValues(alpha: 0.7), // 🆕 Couleur légèrement plus foncée
                ),
              ),
              const SizedBox(height: 4),
              // Total
              Text(
                '${totalAmount.toStringAsFixed(2)} TND',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

