import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../services/kpi_service.dart';
import '../models/kpi_model.dart';

class EnrichedHistorySection extends StatefulWidget {
  const EnrichedHistorySection({super.key});

  @override
  State<EnrichedHistorySection> createState() => _EnrichedHistorySectionState();
}

class _EnrichedHistorySectionState extends State<EnrichedHistorySection> {
  KpiModel? _kpis;
  bool _loading = false;
  String? _error;
  String? _selectedServer;
  String _selectedPeriod = 'ALL';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kpis = await KpiService.loadKpis(
        server: _selectedServer,
        period: _selectedPeriod == 'ALL' ? null : _selectedPeriod,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() {
        _kpis = kpis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '—';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'Historique enrichi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Filtres
              DropdownButton<String>(
                value: _selectedPeriod,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Aujourd\'hui')),
                  DropdownMenuItem(value: 'MIDI', child: Text('Midi')),
                  DropdownMenuItem(value: 'SOIR', child: Text('Soir')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadHistory();
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadHistory,
                tooltip: 'Actualiser',
              ),
            ],
          ),
          const Divider(height: 24),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                  const SizedBox(height: 12),
                  Text('Erreur: $_error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          else if (_kpis == null)
            const Center(child: Text('Aucune donnée disponible'))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Résumé
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HistoryMetric(
                              label: 'CA',
                              value: _formatCurrency(_kpis!.chiffreAffaire),
                              icon: Icons.trending_up,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HistoryMetric(
                              label: 'Encaissé',
                              value: _formatCurrency(_kpis!.totalRecette),
                              icon: Icons.payments,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HistoryMetric(
                              label: 'Tickets',
                              value: '${_kpis!.nombreTickets}',
                              icon: Icons.receipt_long,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Paiements encaissés (derniers)
                    const Text(
                      'Derniers encaissements',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (_kpis!.paidPayments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Aucun paiement encaissé',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._kpis!.paidPayments.take(10).map((payment) {
                        final table = payment['table']?.toString() ?? '?';
                        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                        final timestamp = payment['timestamp']?.toString();
                        final paymentMode = payment['paymentMode']?.toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(Icons.check_circle, color: Colors.green.withValues(alpha: 0.7)),
                            ),
                            title: Text('Table $table'),
                            subtitle: Text('${_formatDate(timestamp)} • ${paymentMode ?? '—'}'),
                            trailing: Text(
                              _formatCurrency(amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    if (_kpis!.paidPayments.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            '... et ${_kpis!.paidPayments.length - 10} autre(s) paiement(s)',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HistoryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

