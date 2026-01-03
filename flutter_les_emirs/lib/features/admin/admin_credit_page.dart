import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/credit_report_model.dart';
import 'services/credit_report_service.dart';

class AdminCreditPage extends StatefulWidget {
  const AdminCreditPage({super.key});

  @override
  State<AdminCreditPage> createState() => _AdminCreditPageState();
}

class _AdminCreditPageState extends State<AdminCreditPage> {
  CreditReport? _report;
  bool _loading = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  final List<String> _periods = const ['ALL', 'MIDI', 'SOIR'];
  final List<String> _servers = const ['ALI', 'FATIMA', 'MOHAMED'];

  String _selectedPeriod = 'ALL';
  String? _selectedServer;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await CreditReportService.loadReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        period: _selectedPeriod,
        server: _selectedServer,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
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

  Future<void> _selectDateRange({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _dateTo = picked.add(const Duration(days: 1));
        }
      } else {
        _dateTo = picked.add(const Duration(days: 1));
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) {
          _dateFrom = picked;
        }
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedPeriod = 'ALL';
      _selectedServer = null;
      _dateFrom = null;
      _dateTo = null;
      _searchCtrl.clear();
    });
    _loadReport();
  }

  Future<void> _printCreditTicket() async {
    final url = CreditReportService.buildTicketUrl(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      period: _selectedPeriod,
      server: _selectedServer,
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le ticket.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crédit client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimer état des crédits',
            onPressed: _printCreditTicket,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _report == null
                        ? _buildEmptyState()
                        : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value: _selectedServer,
                decoration: const InputDecoration(
                  labelText: 'Serveur',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  ..._servers.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedServer = value),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: 'Période',
                  border: OutlineInputBorder(),
                ),
                items: _periods
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedPeriod = value ?? 'ALL'),
              ),
            ),
            SizedBox(
              width: 170,
              child: OutlinedButton.icon(
                onPressed: () => _selectDateRange(isStart: true),
                icon: const Icon(Icons.calendar_today),
                label: Text(_dateFrom == null
                    ? 'Date début'
                    : _formatDateDisplay(_dateFrom!)),
              ),
            ),
            SizedBox(
              width: 170,
              child: OutlinedButton.icon(
                onPressed: () => _selectDateRange(isStart: false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_dateTo == null
                    ? 'Date fin'
                    : _formatDateDisplay(_dateTo!.subtract(const Duration(days: 1)))),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.filter_alt),
              label: const Text('Appliquer'),
            ),
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur inconnue'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadReport,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('Aucune donnée de crédit à afficher.'),
    );
  }

  Widget _buildReportContent() {
    final report = _report!;
    final summary = report.summary;

    final filteredClients = summary.clients.where((client) {
      final term = _searchCtrl.text.trim().toLowerCase();
      if (term.isEmpty) return true;
      return client.clientName.toLowerCase().contains(term);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(summary),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildClientsTable(filteredClients),
          const SizedBox(height: 16),
          _buildTransactionsCard(report.transactions),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(CreditSummary summary) {
    final cards = [
      _SummaryCardData(
        title: 'Dettes émises',
        value: _formatCurrency(summary.totalDebit),
        subtitle: 'Cumuls sur la période',
        color: Colors.deepPurple.shade50,
        icon: Icons.call_received,
        iconColor: Colors.deepPurple,
      ),
      _SummaryCardData(
        title: 'Paiements reçus',
        value: _formatCurrency(summary.totalCredit),
        subtitle: 'Réglements clients',
        color: Colors.green.shade50,
        icon: Icons.call_made,
        iconColor: Colors.green.shade700,
      ),
      _SummaryCardData(
        title: 'Solde en cours',
        value: _formatCurrency(summary.totalBalance),
        subtitle: 'Dettes - paiements',
        color: Colors.orange.shade50,
        icon: Icons.account_balance_wallet,
        iconColor: Colors.orange.shade700,
      ),
      _SummaryCardData(
        title: 'Clients concernés',
        value: summary.clients.length.toString(),
        subtitle: 'Actifs sur la période',
        color: Colors.blue.shade50,
        icon: Icons.people_alt,
        iconColor: Colors.blue.shade700,
      ),
      _SummaryCardData(
        title: 'Mouvements',
        value: summary.transactionsCount.toString(),
        subtitle: 'Transactions crédit/débit',
        color: Colors.teal.shade50,
        icon: Icons.swap_vert,
        iconColor: Colors.teal.shade700,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards
            .map(
              (card) => Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                child: _SummaryCard(data: card),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              ),
        hintText: 'Rechercher un client (nom)',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildClientsTable(List<CreditClient> clients) {
    if (clients.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              const Expanded(child: Text('Aucun client ne correspond aux filtres.')),
            ],
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Dette')),
            DataColumn(label: Text('Paiements')),
            DataColumn(label: Text('Solde')),
            DataColumn(label: Text('Mouvements')),
            DataColumn(label: Text('Dernier mouvement')),
          ],
          rows: clients
              .map(
                (client) => DataRow(
                  cells: [
                    DataCell(Text(client.clientName)),
                    DataCell(Text(_formatCurrency(client.debitTotal))),
                    DataCell(Text(_formatCurrency(client.creditTotal))),
                    DataCell(
                      Text(
                        _formatCurrency(client.balance),
                        style: TextStyle(
                          color: client.balance >= 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(client.transactionsCount.toString())),
                    DataCell(Text(_formatDateTime(client.lastTransaction))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTransactionsCard(List<CreditTransaction> transactions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.pink.shade400),
                const SizedBox(width: 8),
                const Text(
                  'Mouvements récents',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${transactions.length} mouvement(s)'),
              ],
            ),
            const SizedBox(height: 12),
            transactions.isEmpty
                ? const Text('Aucun mouvement enregistré sur cette période.')
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, index) {
                      final tx = transactions[index];
                      final isDebit = tx.type == 'DEBIT';
                      final color = isDebit ? Colors.red : Colors.green;
                      final sign = isDebit ? '+' : '-';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(
                            isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: color,
                          ),
                        ),
                        title: Text('${tx.clientName} • ${tx.type}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tx.date != null) Text(_formatDateTimeValue(tx.date)),
                            Text('${tx.paymentMode} • ${tx.description.isEmpty ? 'Pas de description' : tx.description}'),
                          ],
                        ),
                        trailing: Text(
                          '$sign${_formatCurrency(tx.amount)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: transactions.length,
                  ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        ) +
        ' TND';
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTimeValue(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final IconData icon;

  _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.icon,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.iconColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.iconColor),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

