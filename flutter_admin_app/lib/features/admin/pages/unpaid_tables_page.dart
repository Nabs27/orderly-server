import 'package:flutter/material.dart';
import '../widgets/provisional_ticket_dialog.dart';

class UnpaidTablesPage extends StatefulWidget {
  final List<Map<String, dynamic>> unpaidTables;

  const UnpaidTablesPage({
    super.key,
    required this.unpaidTables,
  });

  @override
  State<UnpaidTablesPage> createState() => _UnpaidTablesPageState();
}

class _UnpaidTablesPageState extends State<UnpaidTablesPage> {
  String? _selectedServer;

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  String _formatDuration(String? dateString) {
    if (dateString == null) return '—';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inHours > 0) {
        return '${diff.inHours}h ${diff.inMinutes % 60}m';
      }
      return '${diff.inMinutes}m';
    } catch (e) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 Collecter les serveurs uniques
    final servers = widget.unpaidTables
        .map((t) => t['server']?.toString() ?? 'unknown')
        .where((s) => s != 'unknown')
        .toSet()
        .toList()
      ..sort();

    // 🆕 Filtrer les tables
    final filteredTables = _selectedServer == null
        ? widget.unpaidTables
        : widget.unpaidTables
            .where((t) => (t['server']?.toString() ?? 'unknown') == _selectedServer)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant, color: Colors.deepOrange),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tables non encaissées',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${filteredTables.length} table(s)',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🆕 Sélecteur de serveur
          if (servers.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text('Filtrer par serveur:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Tous', style: TextStyle(fontSize: 12)),
                            selected: _selectedServer == null,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedServer = null);
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          ...servers.map((server) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(server, style: const TextStyle(fontSize: 12)),
                                selected: _selectedServer == server,
                                onSelected: (selected) {
                                  setState(() => _selectedServer = selected ? server : null);
                                },
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filteredTables.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedServer == null ? Icons.check_circle : Icons.search_off,
                          size: 64,
                          color: _selectedServer == null ? Colors.green.shade300 : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedServer == null
                              ? 'Toutes les tables sont encaissées'
                              : 'Aucune table pour ce serveur',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTables.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final table = filteredTables[index];
                      final tableNumber = table['table']?.toString() ?? '?';
                      final server = table['server']?.toString() ?? 'unknown';
                      final total = (table['total'] as num?)?.toDouble() ?? 0.0;
                      final covers = (table['covers'] as num?)?.toInt() ?? 1;
                      final lastOrderAt = table['lastOrderAt']?.toString();
                      final provisionalTicket = table['provisionalTicket'] as Map<String, dynamic>?;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepOrange.shade100,
                          child: Text(
                            tableNumber.split('_').last,
                            style: TextStyle(
                              color: Colors.deepOrange.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(
                          'Table $tableNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Serveur: $server • $covers couvert(s)',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dernière commande: ${_formatDuration(lastOrderAt)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: false,
                        trailing: SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _formatCurrency(total),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (provisionalTicket != null) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ProvisionalTicketDialog(
                                        ticket: provisionalTicket,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long, size: 14),
                                  label: const Text('Ticket', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    minimumSize: const Size(0, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (filteredTables.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
              ),
              child: Row(
                children: [
                  const Text(
                    'Total: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatCurrency(
                      filteredTables.fold<double>(
                        0.0,
                        (sum, table) => sum + ((table['total'] as num?)?.toDouble() ?? 0.0),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

