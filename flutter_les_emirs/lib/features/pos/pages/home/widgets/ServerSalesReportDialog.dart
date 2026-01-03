import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../admin/models/kpi_model.dart';
import '../../../../../core/api_client.dart';

/// Dialog pour afficher le rapport de ventes d'un serveur
/// Utilise KpiModel pour garantir la cohérence avec le dashboard admin
class ServerSalesReportDialog extends StatelessWidget {
  final String serverName;
  final KpiModel kpis;

  const ServerSalesReportDialog({
    super.key,
    required this.serverName,
    required this.kpis,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Encaissements de $serverName')),
          Text(
            'Journée en cours',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTotalCard(context),
              const SizedBox(height: 16),
              _buildSecondaryStats(context),
              const SizedBox(height: 16),
              _buildPaymentModesSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _printMiniX(context),
          icon: const Icon(Icons.print),
          label: const Text('Imprimer Mini-X'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildTotalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL ENCAISSÉ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(kpis.totalRecette),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChip(
                icon: Icons.receipt_long,
                label: '${kpis.nombreTickets} tickets',
                color: Colors.green.shade200,
              ),
              const SizedBox(width: 8),
              _buildChip(
                icon: Icons.leaderboard,
                label: _formatCurrency(kpis.panierMoyen),
                color: Colors.green.shade200,
              ),
              if (kpis.totalRemises > 0) ...[
                const SizedBox(width: 8),
                _buildChip(
                  icon: Icons.local_offer,
                  label: '-${_formatCurrency(kpis.totalRemises)} remises',
                  color: Colors.orange.shade200,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Chiffre d\'affaires',
            value: _formatCurrency(kpis.chiffreAffaire),
            subtitle: 'CA brut',
            icon: Icons.trending_up,
            color: Colors.blue.shade50,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'Ticket moyen',
            value: _formatCurrency(kpis.panierMoyen),
            subtitle: 'par table',
            icon: Icons.leaderboard,
            color: Colors.purple.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentModesSection() {
    if (kpis.repartitionPaiements.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payment,
        message: 'Aucun paiement enregistré',
      );
    }

    final entries = kpis.repartitionPaiements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Répartition par mode de paiement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.map((entry) {
            final mode = entry.key;
            final percentage = entry.value;
            final amount = (kpis.totalRecette * percentage) / 100;
            return Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(amount),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$title • $subtitle',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  /// Imprimer le mini-X en utilisant l'endpoint backend (comme report_x_page.dart)
  Future<void> _printMiniX(BuildContext context) async {
    try {
      // 🆕 Utiliser les dates d'aujourd'hui (comme le rapport X du dashboard)
      final now = DateTime.now();
      final dateFrom = DateTime(now.year, now.month, now.day);
      final dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      
      final queryParams = <String, String>{
        'server': serverName,
        'period': 'ALL', // Période complète pour la journée
        'dateFrom': dateFrom.toIso8601String(),
        'dateTo': dateTo.toIso8601String(),
        'x-admin-token': 'admin123',
      };

      final baseUrl = ApiClient.dio.options.baseUrl;
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final finalUrl = '$baseUrl/api/admin/report-x-ticket?$queryString';

      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le ticket s\'ouvre dans votre navigateur. Utilisez Ctrl+P pour imprimer.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw 'Impossible d\'ouvrir l\'URL d\'impression';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
