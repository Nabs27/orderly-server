import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

/// Dialog affichant les détails du Chiffre d'Affaires
class CaDetailsDialog extends StatefulWidget {
  final double ca;
  final int nombreTickets;
  final double panierMoyen;

  const CaDetailsDialog({
    super.key,
    required this.ca,
    required this.nombreTickets,
    required this.panierMoyen,
  });

  @override
  State<CaDetailsDialog> createState() => _CaDetailsDialogState();
}

class _CaDetailsDialogState extends State<CaDetailsDialog> {
  Map<String, dynamic>? _reportData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final response = await ApiClient.dio.get(
        '/api/admin/report-x',
        queryParameters: {
          'dateFrom': start.toIso8601String(),
          'dateTo': end.toIso8601String(),
          'period': 'ALL',
        },
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );

      if (mounted) {
        setState(() {
          _reportData = response.data as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  String _formatQuantity(num value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Détails du Chiffre d\'Affaires',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Erreur: $_error', style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetails,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_reportData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 24),
                      _buildServerBreakdown(),
                      const SizedBox(height: 24),
                      _buildPaymentModeBreakdown(),
                      const SizedBox(height: 24),
                      _buildTopCategories(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final unpaidTables = (_reportData?['unpaidTables'] as Map<String, dynamic>?) ?? {};
    final unpaidTotal = (unpaidTables['total'] as num?)?.toDouble() ?? 0.0;
    final unpaidCount = (unpaidTables['count'] as num?)?.toInt() ?? 0;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Synthèse',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'CA Total',
                    _formatCurrency(widget.ca),
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Tickets',
                    '${widget.nombreTickets}',
                    Icons.receipt_long,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Panier moyen',
                    _formatCurrency(widget.panierMoyen),
                    Icons.shopping_cart,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Non encaissé',
                    _formatCurrency(unpaidTotal),
                    Icons.hourglass_bottom,
                    extra: '$unpaidCount table(s)',
                    valueColor: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {String? extra, Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.blue.shade900,
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: 2),
          Text(
            extra,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildServerBreakdown() {
    // Utiliser discountDetails pour avoir les serveurs (contient les serveurs pour les paiements avec remises)
    final discountDetails = (_reportData!['discountDetails'] as List<dynamic>?) ?? [];
    final serverActivity = <String, double>{};
    
    // Calculer le CA par serveur depuis discountDetails (paiements avec remises)
    double totalWithDiscount = 0.0;
    for (final discount in discountDetails) {
      final server = (discount['server'] as String?) ?? 'unknown';
      final amount = (discount['amount'] as num?)?.toDouble() ?? 0.0;
      serverActivity[server] = (serverActivity[server] ?? 0.0) + amount;
      totalWithDiscount += amount;
    }

    // Si on a des données mais pas complètes, on peut estimer la répartition
    // Sinon, on affiche ce qu'on a
    if (serverActivity.isEmpty) {
      // Pas de données de serveur disponibles
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.deepPurple.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Répartition par serveur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Données non disponibles',
                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }
    
    // Si on a seulement une partie du CA (paiements avec remises), on peut ajouter le reste
    final paymentsByMode = (_reportData!['paymentsByMode'] as Map<String, dynamic>?) ?? {};
    double totalPayments = 0.0;
    paymentsByMode.forEach((mode, data) {
      if (mode != 'NON PAYÉ') {
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        totalPayments += total;
      }
    });
    
    // Si on a seulement une partie du CA (paiements avec remises), 
    // on peut estimer la répartition proportionnelle pour le reste
    if (totalPayments > totalWithDiscount && serverActivity.isNotEmpty && totalWithDiscount > 0) {
      final remaining = totalPayments - totalWithDiscount;
      // Répartir le reste proportionnellement selon les parts existantes
      final totalWithDiscountSum = serverActivity.values.fold(0.0, (sum, val) => sum + val);
      if (totalWithDiscountSum > 0) {
        final updatedActivity = <String, double>{};
        serverActivity.forEach((server, amount) {
          final proportion = amount / totalWithDiscountSum;
          updatedActivity[server] = amount + (remaining * proportion);
        });
        serverActivity.clear();
        serverActivity.addAll(updatedActivity);
      }
    }

    final sortedServers = serverActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepPurple.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Répartition par serveur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sortedServers.map((entry) {
              final percent = widget.ca > 0 ? (entry.value / widget.ca) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatCurrency(entry.value),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade300),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeBreakdown() {
    final paymentsByMode = (_reportData!['paymentsByMode'] as Map<String, dynamic>?) ?? {};
    
    if (paymentsByMode.isEmpty) {
      return const SizedBox.shrink();
    }

    final modes = <MapEntry<String, Map<String, dynamic>>>[];
    paymentsByMode.forEach((mode, data) {
      if (mode != 'NON PAYÉ') {
        modes.add(MapEntry(mode, data as Map<String, dynamic>));
      }
    });

    modes.sort((a, b) {
      final totalA = (a.value['total'] as num?)?.toDouble() ?? 0.0;
      final totalB = (b.value['total'] as num?)?.toDouble() ?? 0.0;
      return totalB.compareTo(totalA);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Répartition par mode de paiement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...modes.map((entry) {
              final mode = entry.key;
              final data = entry.value;
              final total = (data['total'] as num?)?.toDouble() ?? 0.0;
              final count = (data['count'] as int?) ?? 0;
              final percent = widget.ca > 0 ? (total / widget.ca) * 100 : 0.0;

              IconData icon;
              Color color;
              switch (mode) {
                case 'ESPECE':
                  icon = Icons.money;
                  color = Colors.green;
                  break;
                case 'CARTE':
                  icon = Icons.credit_card;
                  color = Colors.blue;
                  break;
                case 'CHEQUE':
                  icon = Icons.description;
                  color = Colors.orange;
                  break;
                default:
                  icon = Icons.payment;
                  color = Colors.grey;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: 8),
                            Text(
                              mode,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($count)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Text(
                          _formatCurrency(total),
                          style: TextStyle(fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategories() {
    final itemsByCategory = (_reportData!['itemsByCategory'] as Map<String, dynamic>?) ?? {};
    
    if (itemsByCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    final categories = <MapEntry<String, double>>[];
    itemsByCategory.forEach((category, data) {
      final total = (data['totalValue'] as num?)?.toDouble() ?? 0.0;
      if (total > 0) {
        categories.add(MapEntry(category, total));
      }
    });

    categories.sort((a, b) => b.value.compareTo(a.value));
    final top5 = categories.take(5).toList();

    if (top5.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Top 5 catégories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top5.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value.key;
              final total = entry.value.value;
              final percent = widget.ca > 0 ? (total / widget.ca) * 100 : 0.0;
              final categoryData =
                  itemsByCategory[category] as Map<String, dynamic>? ?? {};

              return InkWell(
                onTap: () => _showCategoryDetails(category, categoryData),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Icon(Icons.open_in_new,
                                    size: 16, color: Colors.orange.shade700),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percent / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(total),
                            style:
                                TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                          ),
                          Text(
                            '${percent.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  void _showCategoryDetails(String category, Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final totalQuantity = (data['totalQuantity'] as num?)?.toDouble() ?? 0.0;
    final totalValue = (data['totalValue'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.category, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(category),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: items.isEmpty
              ? const Text('Aucun article dans cette catégorie pour la période.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ${_formatCurrency(totalValue)} • ${_formatQuantity(totalQuantity)} article(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final name = item['name'] as String? ?? 'Article';
                          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                          final value = (item['total'] as num?)?.toDouble() ??
                              ((item['price'] as num?)?.toDouble() ?? 0.0) * quantity;

                          return ListTile(
                            dense: true,
                            title: Text(name),
                            subtitle: Text('Qté: ${_formatQuantity(quantity)}'),
                            trailing: Text(
                              _formatCurrency(value),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

