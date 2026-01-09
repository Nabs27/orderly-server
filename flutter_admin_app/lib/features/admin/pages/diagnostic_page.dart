import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/diagnostic_service.dart';

/// Page de diagnostic pour comparer les données entre les différentes sources
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final _tableController = TextEditingController(text: '1');
  Map<String, dynamic>? _diagnosticData;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostic() async {
    final tableNumber = _tableController.text.trim();
    if (tableNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro de table')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await DiagnosticService.diagnoseTable(tableNumber);
      setState(() {
        _diagnosticData = data;
        _loading = false;
      });
      
      // Logger aussi dans la console
      DiagnosticService.logDiagnostic(data);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Lancer le diagnostic pour la table 1 par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDiagnostic();
    });
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange),
            SizedBox(width: 8),
            Text('Diagnostic des données'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostic,
            tooltip: 'Relancer le diagnostic',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche de table
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text(
                  'Table:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _tableController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _runDiagnostic(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _runDiagnostic,
                  icon: const Icon(Icons.search),
                  label: const Text('Diagnostiquer'),
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text('Erreur: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _runDiagnostic,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _diagnosticData != null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummary(),
                                const SizedBox(height: 24),
                                _buildSources(),
                                const SizedBox(height: 24),
                                _buildComparison(),
                                const SizedBox(height: 24),
                                _buildDetails(),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final comparison = _diagnosticData?['comparison'] as Map<String, dynamic>?;
    final differencesCount = (comparison?['differences_count'] as int?) ?? 0;
    final table = _diagnosticData?['table']?.toString() ?? '?';
    
    return Card(
      color: differencesCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  differencesCount > 0 ? Icons.warning : Icons.check_circle,
                  color: differencesCount > 0 ? Colors.orange : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résumé du diagnostic - Table $table',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: differencesCount > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timestamp: ${_diagnosticData?['timestamp']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Différences',
                  differencesCount.toString(),
                  differencesCount > 0 ? Colors.orange : Colors.green,
                ),
                _buildSummaryItem(
                  'OrderIds',
                  '${(comparison?['all_orderIds'] as List?)?.length ?? 0}',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSources() {
    final sources = _diagnosticData?['sources'] as Map<String, dynamic>? ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sources de données',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildSourceCard('report_x', '📊 Report-X (KPI)', sources['report_x']),
        const SizedBox(height: 12),
        _buildSourceCard('history_unified', '📋 History Unified (Plan de table)', sources['history_unified']),
        const SizedBox(height: 12),
        _buildSourceCard('orders_direct', '📦 Orders Direct', sources['orders_direct']),
      ],
    );
  }

  Widget _buildSourceCard(String sourceKey, String title, Map<String, dynamic>? sourceData) {
    if (sourceData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title: Données non disponibles'),
        ),
      );
    }

    if (sourceData.containsKey('error')) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('❌ Erreur: ${sourceData['error']}', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    final summary = sourceData['summary'] as Map<String, dynamic>?;
    
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title),
        subtitle: Text(_getSourceSubtitle(sourceKey, sourceData)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSourceDetails(sourceKey, sourceData, summary),
          ),
        ],
      ),
    );
  }

  String _getSourceSubtitle(String sourceKey, Map<String, dynamic> sourceData) {
    switch (sourceKey) {
      case 'report_x':
        final count = sourceData['paidPayments_table_count'] ?? 0;
        return '$count paiement(s) trouvé(s)';
      case 'history_unified':
        final count = sourceData['orders_table_count'] ?? 0;
        return '$count commande(s) trouvée(s)';
      case 'orders_direct':
        final count = sourceData['orders_table_count'] ?? 0;
        return '$count commande(s) trouvée(s)';
      default:
        return 'Données disponibles';
    }
  }

  Widget _buildSourceDetails(String sourceKey, Map<String, dynamic> sourceData, Map<String, dynamic>? summary) {
    if (summary == null) {
      return const Text('Aucun résumé disponible');
    }

    switch (sourceKey) {
      case 'report_x':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Paiements', '${summary['payments_count'] ?? 0}'),
            _buildDetailRow('Montant total', _formatCurrency(summary['totalAmount'] ?? 0.0)),
            _buildDetailRow('Subtotal', _formatCurrency(summary['totalSubtotal'] ?? 0.0)),
            _buildDetailRow('Remise', _formatCurrency(summary['totalDiscount'] ?? 0.0)),
            if (summary['totalEntered'] != null)
              _buildDetailRow('Montant encaissé', _formatCurrency(summary['totalEntered'])),
            if (summary['totalExcess'] != null)
              _buildDetailRow('Pourboire', _formatCurrency(summary['totalExcess']), Colors.amber),
            _buildDetailRow('Paiements divisés', '${summary['splitPayments_count'] ?? 0}'),
            _buildDetailRow('Modes de paiement', '${summary['modes']}'),
            _buildDetailRow('OrderIds', '${summary['orderIds']}'),
            const SizedBox(height: 16),
            const Text('Détails des paiements:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...((sourceData['paidPayments'] as List<dynamic>?) ?? []).asMap().entries.map((entry) {
              final index = entry.key;
              final payment = entry.value as Map<String, dynamic>;
              return _buildPaymentDetailCard(index + 1, payment);
            }),
          ],
        );
        
      case 'history_unified':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Commandes', '${summary['orders_count'] ?? 0}'),
            _buildDetailRow('Montant total', _formatCurrency(summary['totalAmount'] ?? 0.0)),
            _buildDetailRow('Services détectés', '${summary['services_count'] ?? 0}'),
            _buildDetailRow('OrderIds', '${summary['orderIds']}'),
            const SizedBox(height: 16),
            const Text('Détails des commandes:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...((sourceData['orders'] as List<dynamic>?) ?? []).asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value as Map<String, dynamic>;
              return _buildOrderDetailCard(index + 1, order);
            }),
          ],
        );
        
      case 'orders_direct':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Commandes', '${summary['orders_count'] ?? 0}'),
            _buildDetailRow('Montant total', _formatCurrency(summary['totalAmount'] ?? 0.0)),
            _buildDetailRow('OrderIds', '${summary['orderIds']}'),
          ],
        );
        
      default:
        return const Text('Détails non disponibles');
    }
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailCard(int index, Map<String, dynamic> payment) {
    final isSplit = payment['isSplitPayment'] == true;
    final splitId = payment['splitPaymentId']?.toString();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        title: Text('Paiement #$index'),
        subtitle: Text(
          '${payment['paymentMode']} • ${_formatCurrency(payment['amount'])}'
          '${isSplit ? ' • DIVISÉ' : ''}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('OrderId', payment['orderId']?.toString() ?? '?'),
                if (payment['orderIds'] != null)
                  _buildDetailRow('OrderIds', '${payment['orderIds']}'),
                _buildDetailRow('Timestamp', payment['timestamp']?.toString() ?? '?'),
                _buildDetailRow('Mode', payment['paymentMode']?.toString() ?? '?'),
                _buildDetailRow('Montant', _formatCurrency(payment['amount'])),
                _buildDetailRow('Subtotal', _formatCurrency(payment['subtotal'])),
                _buildDetailRow('Remise', _formatCurrency(payment['discountAmount'])),
                if (payment['enteredAmount'] != null)
                  _buildDetailRow('Montant encaissé', _formatCurrency(payment['enteredAmount'])),
                if (payment['excessAmount'] != null && (payment['excessAmount'] as num).toDouble() > 0.01)
                  _buildDetailRow('Pourboire', _formatCurrency(payment['excessAmount']), Colors.amber),
                _buildDetailRow('Serveur', payment['server']?.toString() ?? '?'),
                _buildDetailRow('Couverts', '${payment['covers']}'),
                _buildDetailRow('Articles', '${payment['items_count']}'),
                if (isSplit) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paiement divisé', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                        Text('SplitPaymentId: $splitId'),
                        if (payment['splitPaymentAmounts'] != null) ...[
                          const SizedBox(height: 8),
                          const Text('Détails:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...((payment['splitPaymentAmounts'] as List<dynamic>?) ?? []).map((s) {
                            final split = s as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                '${split['mode']}: ${_formatCurrency(split['amount'])}'
                                '${split['clientName'] != null ? ' (${split['clientName']})' : ''}',
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
                if (payment['ticket'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ticket:', style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildDetailRow('Total', _formatCurrency((payment['ticket']['total'] as num?)?.toDouble() ?? 0.0)),
                        if (payment['ticket']['totalAmount'] != null)
                          _buildDetailRow('Montant encaissé', _formatCurrency(payment['ticket']['totalAmount'])),
                        if (payment['ticket']['excessAmount'] != null)
                          _buildDetailRow('Pourboire', _formatCurrency(payment['ticket']['excessAmount']), Colors.amber),
                        if (payment['ticket']['paymentDetails'] != null) ...[
                          const SizedBox(height: 4),
                          const Text('Détails paiement:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ...((payment['ticket']['paymentDetails'] as List<dynamic>?) ?? []).map((d) {
                            final detail = d as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(left: 16, top: 2),
                              child: Text(
                                '${detail['mode']}: ${_formatCurrency(detail['amount'])}'
                                '${detail['clientName'] != null ? ' (${detail['clientName']})' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailCard(int index, Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.purple.shade50,
      child: ExpansionTile(
        title: Text('Commande #${order['orderId']}'),
        subtitle: Text('${_formatCurrency(order['total'])} • ${order['paymentHistory_count']} paiement(s)'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('OrderId', order['orderId']?.toString() ?? '?'),
                _buildDetailRow('Table', order['table']?.toString() ?? '?'),
                _buildDetailRow('Serveur', order['server']?.toString() ?? '?'),
                _buildDetailRow('Status', order['status']?.toString() ?? '?'),
                _buildDetailRow('Total', _formatCurrency(order['total'])),
                _buildDetailRow('Créée le', order['createdAt']?.toString() ?? '?'),
                if (order['archivedAt'] != null)
                  _buildDetailRow('Archivée le', order['archivedAt']?.toString() ?? '?'),
                _buildDetailRow('Paiements', '${order['paymentHistory_count']}'),
                if (order['paymentHistory'] != null && (order['paymentHistory'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Historique paiements:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...((order['paymentHistory'] as List<dynamic>)).map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '${p['timestamp']} • ${p['paymentMode']} • ${_formatCurrency(p['amount'])}'
                        '${p['isSplitPayment'] == true ? ' • DIVISÉ (${p['splitPaymentId']})' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    final comparison = _diagnosticData?['comparison'] as Map<String, dynamic>?;
    final differences = (comparison?['differences'] as Map<String, dynamic>?) ?? {};
    
    if (differences.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('✅ Aucune différence détectée entre les sources'),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ Différences détectées',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 12),
        ...differences.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.orange.shade50,
            child: ExpansionTile(
              title: Text(entry.key),
              subtitle: const Text('⚠️ Différence détectée'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDifferenceDetails(entry.key, entry.value),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDifferenceDetails(String key, dynamic value) {
    if (value is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...value.entries.map((e) {
            if (e.value is num) {
              return _buildDetailRow(e.key, _formatCurrency((e.value as num).toDouble()));
            } else if (e.value is List) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...((e.value as List).map((item) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: Text(item.toString(), style: const TextStyle(fontSize: 12)),
                    ))),
                  ],
                ),
              );
            } else {
              return _buildDetailRow(e.key, e.value.toString());
            }
          }),
        ],
      );
    }
    return Text(value.toString());
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Données brutes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                final json = _diagnosticData.toString();
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Données copiées dans le presse-papier')),
                );
              },
              tooltip: 'Copier les données JSON',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                _diagnosticData.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
