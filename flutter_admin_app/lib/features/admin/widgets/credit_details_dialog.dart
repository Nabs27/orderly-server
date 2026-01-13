import 'package:flutter/material.dart';

class CreditDetailsDialog extends StatefulWidget {
  final double totalDebit;
  final double totalCredit;
  final double totalBalance;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> recentTransactions;

  const CreditDetailsDialog({
    super.key,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalBalance,
    required this.clients,
    required this.recentTransactions,
  });

  @override
  State<CreditDetailsDialog> createState() => _CreditDetailsDialogState();
}

class _CreditDetailsDialogState extends State<CreditDetailsDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredClients = widget.clients.where((client) {
      final term = _searchCtrl.text.trim().toLowerCase();
      if (term.isEmpty) return true;
      final name = (client['clientName'] as String? ?? '').toLowerCase();
      return name.contains(term);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.pink.shade600),
          const SizedBox(width: 8),
          const Text('Détails crédit client'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un client…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildClientsList(filteredClients)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTransactionsList()),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        )
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryChip('Dettes émises', widget.totalDebit, Colors.deepPurple),
        _buildSummaryChip('Paiements reçus', widget.totalCredit, Colors.blue),
        _buildSummaryChip('Solde en cours', widget.totalBalance,
            widget.totalBalance >= 0 ? Colors.orange : Colors.green),
      ],
    );
  }

  Widget _buildSummaryChip(String label, double value, Color color) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.1),
      label: SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11)),
            Text(
              _formatCurrency(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsList(List<Map<String, dynamic>> clients) {
    if (clients.isEmpty) {
      return _emptyState('Aucun client trouvé');
    }

    return Card(
      child: ListView.separated(
        itemCount: clients.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final client = clients[index];
          final name = client['clientName'] as String? ?? 'N/A';
          final balance = (client['balance'] as num?)?.toDouble() ?? 0.0;
          final debit = (client['debitTotal'] as num?)?.toDouble() ?? 0.0;
          final credit = (client['creditTotal'] as num?)?.toDouble() ?? 0.0;
          final count = (client['transactionsCount'] as num?)?.toInt() ?? 0;
          final last = client['lastTransaction'] as String?;

          return ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dette: ${_formatCurrency(debit)}'),
                Text('Paiements: ${_formatCurrency(credit)}'),
                if (last != null)
                  Text('Dernier mouvement: ${_formatDate(last)}'),
              ],
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCurrency(balance),
                  style: TextStyle(
                    color: balance >= 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('$count mouvement(s)', style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (widget.recentTransactions.isEmpty) {
      return _emptyState('Aucun mouvement récent');
    }

    return Card(
      child: ListView.separated(
        itemCount: widget.recentTransactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final tx = widget.recentTransactions[index];
          final name = tx['clientName'] as String? ?? 'N/A';
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final type = (tx['type'] as String? ?? 'DEBIT').toUpperCase();
          final mode = tx['paymentMode'] as String? ?? 'CREDIT';
          final date = tx['date'] as String?;
          final description = tx['description'] as String? ?? '';
          final color = type == 'DEBIT' ? Colors.red : Colors.green;
          final sign = type == 'DEBIT' ? '+' : '-';

          return ListTile(
            leading: Icon(Icons.receipt_long, color: color),
            title: Text('$name • $type'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date != null) Text(_formatDate(date)),
                Text(description.isEmpty ? mode : '$mode • $description'),
              ],
            ),
            trailing: Text(
              '$sign${_formatCurrency(amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade600)),
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

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

