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
    final discountDetails = (_reportData!['discountDetails'] as List<dynamic>?) ?? [];
    final serverActivity = <String, double>{};
    
    double totalWithDiscount = 0.0;
    for (final discount in discountDetails) {
      final server = (discount['server'] as String?) ?? 'unknown';
      final amount = (discount['amount'] as num?)?.toDouble() ?? 0.0;
      serverActivity[server] = (serverActivity[server] ?? 0.0) + amount;
      totalWithDiscount += amount;
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
    
    final paymentsByMode = (_reportData!['paymentsByMode'] as Map<String, dynamic>?) ?? {};
    double totalPayments = 0.0;
    paymentsByMode.forEach((mode, data) {
      if (mode != 'NON PAYÉ') {
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        totalPayments += total;
      }
    });
    
    if (totalPayments > totalWithDiscount && serverActivity.isNotEmpty && totalWithDiscount > 0) {
      final remaining = totalPayments - totalWithDiscount;
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
    final paidPayments = (_reportData!['paidPayments'] as List<dynamic>?) ?? [];
    
    if (paymentsByMode.isEmpty) {
      return const SizedBox.shrink();
    }

    // 🆕 Collecter les détails des paiements divisés depuis paidPayments
    final splitPaymentDetails = <String, List<Map<String, dynamic>>>{}; // mode -> liste de détails
    for (final payment in paidPayments) {
      final isSplit = payment['isSplitPayment'] == true;
      final splitAmounts = payment['splitPaymentAmounts'] as List<dynamic>?;
      
      if (isSplit && splitAmounts != null) {
        // Dédupliquer par mode + amount pour éviter les doublons
        final processedTxs = <String>{};
        for (final splitDetail in splitAmounts) {
          final splitMode = (splitDetail['mode'] as String?) ?? '';
          final splitAmount = (splitDetail['amount'] as num?)?.toDouble() ?? 0.0;
          final txKey = '${splitMode}_${splitAmount.toStringAsFixed(3)}';
          
          if (!processedTxs.contains(txKey) && splitMode.isNotEmpty && splitAmount > 0.01) {
            processedTxs.add(txKey);
            if (!splitPaymentDetails.containsKey(splitMode)) {
              splitPaymentDetails[splitMode] = [];
            }
            splitPaymentDetails[splitMode]!.add({
              'amount': splitAmount,
              'table': payment['table']?.toString() ?? '—',
              'clientName': splitDetail['clientName'] as String?,
            });
          }
        }
      }
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

              // 🆕 Récupérer les détails des paiements divisés pour ce mode
              final splitDetails = splitPaymentDetails[mode] ?? [];
              final hasSplitDetails = splitDetails.isNotEmpty;

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
                    // 🆕 Afficher les détails des paiements divisés si disponibles
                    if (hasSplitDetails) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: splitDetails.asMap().entries.map((detailEntry) {
                            final index = detailEntry.key;
                            final detail = detailEntry.value;
                            final detailAmount = (detail['amount'] as num?)?.toDouble() ?? 0.0;
                            final detailTable = detail['table']?.toString() ?? '—';
                            final clientName = detail['clientName'] as String?;
                            
                            // 🆕 Afficher le nom du client pour les paiements CREDIT (comme dans l'historique)
                            final displayLabel = mode == 'CREDIT' && clientName != null
                                ? 'CREDIT ($clientName)'
                                : '${mode} #${index + 1}';
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatCurrency(detailAmount),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
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
}

