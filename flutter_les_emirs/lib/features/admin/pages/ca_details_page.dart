import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

/// Page plein écran affichant les détails du Chiffre d'Affaires
class CaDetailsPage extends StatefulWidget {
  final double ca;
  final int nombreTickets;
  final double panierMoyen;

  const CaDetailsPage({
    super.key,
    required this.ca,
    required this.nombreTickets,
    required this.panierMoyen,
  });

  @override
  State<CaDetailsPage> createState() => _CaDetailsPageState();
}

class _CaDetailsPageState extends State<CaDetailsPage> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, color: Colors.blue),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Détails du Chiffre d\'Affaires',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : _reportData != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummary(),
                          const SizedBox(height: 24),
                          _buildServerBreakdown(),
                          const SizedBox(height: 24),
                          _buildPaymentModeBreakdown(),
                          const SizedBox(height: 24),
                          _buildTipsBreakdown(),
                          const SizedBox(height: 24),
                          _buildTopCategories(),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Row(
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
                  );
                } else {
                  return Column(
                    children: [
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
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
                  );
                }
              },
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
    // 🆕 CORRECTION : Utiliser paidPayments comme source principale (plus fiable que discountDetails uniquement)
    // discountDetails peut être vide même si des paiements existent
    final paidPayments = (_reportData!['paidPayments'] as List<dynamic>?) ?? [];
    final discountDetails = (_reportData!['discountDetails'] as List<dynamic>?) ?? [];
    final serverActivity = <String, double>{};
    
    // 🆕 Méthode 1 : Collecter depuis paidPayments (source de vérité principale)
    for (final payment in paidPayments) {
      final server = (payment['server'] as String?)?.trim().toUpperCase() ?? 'UNKNOWN';
      if (server.isEmpty || server == 'UNKNOWN') continue;
      
      // Utiliser totalAmount du ticket (montant réellement encaissé) si disponible, sinon amount
      final ticket = payment['ticket'] as Map<String, dynamic>?;
      final totalAmount = (ticket?['totalAmount'] as num?)?.toDouble();
      final amount = totalAmount ?? (payment['amount'] as num?)?.toDouble() ?? 0.0;
      
      // Exclure CREDIT du calcul (c'est une dette différée, pas un encaissement réel)
      if ((payment['paymentMode'] as String?) == 'CREDIT') continue;
      
      if (amount > 0.01) {
        serverActivity[server] = (serverActivity[server] ?? 0.0) + amount;
      }
    }
    
    // 🆕 Méthode 2 : Compléter avec discountDetails si serverActivity est vide (fallback)
    if (serverActivity.isEmpty && discountDetails.isNotEmpty) {
      for (final discount in discountDetails) {
        final server = ((discount['server'] as String?) ?? 'unknown').trim().toUpperCase();
        if (server.isEmpty || server == 'UNKNOWN') continue;
        final amount = (discount['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0.01) {
          serverActivity[server] = (serverActivity[server] ?? 0.0) + amount;
        }
      }
    }

    if (serverActivity.isEmpty) {
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

    // 🆕 CORRECTION : Trier par ordre alphabétique puis par montant décroissant pour un ordre cohérent
    final sortedServers = serverActivity.entries.toList()
      ..sort((a, b) {
        // D'abord trier par montant décroissant
        final amountComparison = b.value.compareTo(a.value);
        if (amountComparison != 0) return amountComparison;
        // En cas d'égalité, trier alphabétiquement par nom de serveur
        return a.key.compareTo(b.key);
      });

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
      if (mode != 'NON PAYÉ' && mode != '_tipsByServer') {
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
                case 'CREDIT':
                  icon = Icons.account_balance_wallet;
                  color = Colors.deepPurple;
                  break;
                case 'TPE':
                  icon = Icons.payment;
                  color = Colors.teal;
                  break;
                default:
                  icon = Icons.payment;
                  color = Colors.grey;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showPaymentModeDetails(context, mode, data),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
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
                            Row(
                              children: [
                                Text(
                                  _formatCurrency(total),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: color.withOpacity(0.7),
                                ),
                              ],
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
                  ),
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ligne 1 : Badge numéro + Nom catégorie + Icône
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.open_in_new,
                              size: 16, color: Colors.orange.shade600),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Ligne 2 : Barre de progression
                      SizedBox(
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: Colors.orange.shade100,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.orange.shade400),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ligne 3 : Montant et pourcentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${percent.toStringAsFixed(1)}% du CA',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            _formatCurrency(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.orange.shade700,
                            ),
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

  Widget _buildTipsBreakdown() {
    final paymentsByMode = (_reportData!['paymentsByMode'] as Map<String, dynamic>?) ?? {};
    final tipsByServer = paymentsByMode['_tipsByServer'] as Map<String, dynamic>?;
    
    if (tipsByServer == null || tipsByServer.isEmpty) {
      return const SizedBox.shrink();
    }

    final tips = <MapEntry<String, double>>[];
    tipsByServer.forEach((server, amount) {
      final tipAmount = (amount as num?)?.toDouble() ?? 0.0;
      if (tipAmount > 0.01) {
        tips.add(MapEntry(server, tipAmount));
      }
    });

    if (tips.isEmpty) {
      return const SizedBox.shrink();
    }

    tips.sort((a, b) => b.value.compareTo(a.value));
    final totalTips = tips.fold(0.0, (sum, entry) => sum + entry.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Pourboires par serveur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map((entry) {
              final server = entry.key;
              final tipAmount = entry.value;
              final percent = totalTips > 0 ? (tipAmount / totalTips) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          server,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatCurrency(tipAmount),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade300),
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
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total pourboires',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatCurrency(totalTips),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 800 ? 800.0 : screenWidth * 0.95;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: 800,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.category, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun article dans cette catégorie pour la période.'),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total: ${_formatCurrency(totalValue)} • ${_formatQuantity(totalQuantity)} article(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentModeDetails(BuildContext context, String mode, Map<String, dynamic> data) {
    final count = (data['count'] as int?) ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final paidPayments = (_reportData!['paidPayments'] as List<dynamic>?) ?? [];

    // Collecter tous les paiements de ce mode (simples + divisés)
    final allPayments = <Map<String, dynamic>>[];

    // Récupérer les détails des paiements divisés pour ce mode
    final splitPaymentDetails = <String, List<Map<String, dynamic>>>{};
    for (final payment in paidPayments) {
      final isSplit = payment['isSplitPayment'] == true;
      final splitAmounts = payment['splitPaymentAmounts'] as List<dynamic>?;

      if (isSplit && splitAmounts != null) {
        for (final splitDetail in splitAmounts) {
          final splitMode = (splitDetail['mode'] as String?) ?? '';
          final splitAmount = (splitDetail['amount'] as num?)?.toDouble() ?? 0.0;
          final splitIndex = splitDetail['index'];

          if (splitMode.isNotEmpty && splitAmount > 0.01) {
            if (!splitPaymentDetails.containsKey(splitMode)) {
              splitPaymentDetails[splitMode] = [];
            }
            
            // Récupérer le timestamp du paiement parent pour l'affichage
            String timeStr = '—';
            try {
              if (payment['timestamp'] != null) {
                final dt = DateTime.parse(payment['timestamp'].toString()).toLocal();
                timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
              }
            } catch (e) {
              // Garder "—" si erreur de parsing
            }

            splitPaymentDetails[splitMode]!.add({
              'amount': splitAmount,
              'table': payment['table']?.toString() ?? '—',
              'clientName': splitDetail['clientName'] as String?,
              'time': timeStr,
              'index': splitIndex, // Optionnel : pour debug ou affichage futur
            });
          }
        }
      }
    }

    // Ajouter les paiements divisés pour ce mode
    final splitDetails = splitPaymentDetails[mode] ?? [];
    allPayments.addAll(splitDetails);

    // Ajouter les paiements simples du même mode
    for (final payment in paidPayments) {
      if (payment['paymentMode'] == mode && payment['isSplitPayment'] != true) {
        final enteredAmount = payment['enteredAmount'] != null ? payment['enteredAmount'] : (payment['amount'] ?? 0);
        final table = payment['table']?.toString() ?? '—';
        final timestamp = payment['timestamp'] as String?;
        final timeStr = timestamp != null
            ? DateTime.parse(timestamp).toLocal().toString().substring(11, 16) // HH:MM
            : '—';

        // Pour les paiements simples CREDIT, récupérer le nom du client
        String? clientName;
        if (mode == 'CREDIT') {
          clientName = payment['creditClientName'] as String?;
        }

        allPayments.add({
          'amount': enteredAmount,
          'table': table,
          'time': timeStr,
          'clientName': clientName,
        });
      }
    }

    // Trier par heure décroissante (plus récent en haut)
    allPayments.sort((a, b) {
      final timeA = a['time'] as String?;
      final timeB = b['time'] as String?;
      if (timeA == null || timeB == null) return 0;
      return timeB.compareTo(timeA);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 800 ? 600.0 : screenWidth * 0.9;

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
      case 'CREDIT':
        icon = Icons.account_balance_wallet;
        color = Colors.deepPurple;
        break;
      case 'TPE':
        icon = Icons.payment;
        color = Colors.teal;
        break;
      default:
        icon = Icons.payment;
        color = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 600,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paiements $mode',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '$count paiement(s) • ${_formatCurrency(total)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Liste des paiements
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: allPayments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final payment = allPayments[index];
                    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                    final table = payment['table'] as String? ?? '—';
                    final time = payment['time'] as String? ?? '—';
                    final clientName = payment['clientName'] as String?;

                    final displayLabel = mode == 'CREDIT' && clientName != null && clientName.isNotEmpty
                        ? '$mode ($clientName)'
                        : mode;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Table $table',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(displayLabel),
                      trailing: Text(
                        _formatCurrency(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

