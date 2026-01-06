import 'package:flutter/material.dart';
import '../widgets/payment_ticket_card.dart';

class DiscountDetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> discountDetails;

  const DiscountDetailsPage({super.key, required this.discountDetails});

  @override
  State<DiscountDetailsPage> createState() => _DiscountDetailsPageState();
}

class _DiscountDetailsPageState extends State<DiscountDetailsPage> {
  final TextEditingController _tableFilter = TextEditingController();
  String? _selectedServer;

  @override
  void dispose() {
    _tableFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allServers = <String>{};
    for (final discount in widget.discountDetails) {
      final server = discount['server'] as String?;
      if (server != null && server != 'unknown' && server.isNotEmpty) {
        allServers.add(server);
      }
    }
    final sortedServers = allServers.toList()..sort();

    final serverStats = <String, _ServerStats>{};
    for (final discount in widget.discountDetails) {
      final server = discount['server'] as String? ?? 'unknown';
      final amount = (discount['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final stats = serverStats.putIfAbsent(server, () => _ServerStats());
      stats.total += amount;
      stats.count += 1;
    }

    final totalRemisesGlobal = serverStats.values.fold<double>(0, (sum, stats) => sum + stats.total);
    final totalRemisesGlobalCount = serverStats.values.fold<int>(0, (sum, stats) => sum + stats.count);

    final filtered = widget.discountDetails.where((discount) {
      final tableFilter = _tableFilter.text.trim().toLowerCase();
      if (tableFilter.isNotEmpty) {
        final table = (discount['table'] as String? ?? '').toLowerCase();
        if (!table.contains(tableFilter)) return false;
      }
      
      if (_selectedServer != null) {
        final server = discount['server'] as String? ?? 'unknown';
        if (server != _selectedServer) return false;
      }
      
      return true;
    }).toList();

    final totalRemisesFiltre = filtered.fold<double>(
      0,
      (sum, discount) => sum + ((discount['discountAmount'] as num?)?.toDouble() ?? 0.0),
    );
    final nombreRemisesFiltre = filtered.length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.percent, color: Colors.amber),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Détails des remises',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (sortedServers.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildServerChip(
                        label: 'Tous',
                        total: totalRemisesGlobal,
                        count: totalRemisesGlobalCount,
                        icon: _selectedServer == null ? Icons.check_circle : Icons.circle_outlined,
                        isSelected: _selectedServer == null,
                        selectedColor: Colors.amber.shade700,
                        onSelected: (selected) {
                          setState(() {
                            _selectedServer = null;
                          });
                        },
                      ),
                    ),
                    ...sortedServers.map((server) {
                      final isSelected = _selectedServer == server;
                      final stats = serverStats[server];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildServerChip(
                          label: server,
                          total: stats?.total ?? 0.0,
                          count: stats?.count ?? 0,
                          icon: isSelected ? Icons.person : Icons.person_outline,
                          isSelected: isSelected,
                          selectedColor: Colors.blue.shade700,
                          onSelected: (selected) {
                            setState(() {
                              _selectedServer = selected ? server : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _tableFilter,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list),
                hintText: 'Filtrer par table (ex: A3)…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total (filtre actif) : ${_formatCurrency(totalRemisesFiltre)} • $nombreRemisesFiltre remises',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final discount = filtered[index];
                        final table = discount['table'] ?? 'N/A';
                        final server = discount['server'] ?? 'unknown';
                        final noteName = discount['noteName'] ?? 'Note';
                        final discountClientName = discount['discountClientName'] as String?;
                        final rate = discount['discount'] ?? 0;
                        final isPercent = discount['isPercentDiscount'] == true;
                        final timestamp = discount['timestamp'] as String? ?? '';

                        final savedTicket = discount['ticket'] as Map<String, dynamic>?;
                        final items = savedTicket != null
                            ? (savedTicket['items'] as List? ?? []).cast<Map<String, dynamic>>()
                            : (discount['items'] as List? ?? []).cast<Map<String, dynamic>>();
                        
                        final finalSubtotal = savedTicket != null
                            ? (savedTicket['subtotal'] as num?)?.toDouble() ?? (discount['subtotal'] as num?)?.toDouble() ?? 0.0
                            : (discount['subtotal'] as num?)?.toDouble() ?? 0.0;
                        final finalDiscountAmount = savedTicket != null
                            ? (savedTicket['discountAmount'] as num?)?.toDouble() ?? (discount['discountAmount'] as num?)?.toDouble() ?? 0.0
                            : (discount['discountAmount'] as num?)?.toDouble() ?? 0.0;
                        final finalAmount = savedTicket != null
                            ? (savedTicket['total'] as num?)?.toDouble() ?? (discount['amount'] as num?)?.toDouble() ?? 0.0
                            : (discount['amount'] as num?)?.toDouble() ?? 0.0;

                        return InkWell(
                          onTap: () => _showTicketDialog(
                            context,
                            discount,
                            table,
                            server,
                            noteName,
                            discountClientName,
                            timestamp,
                            items,
                            finalSubtotal,
                            finalDiscountAmount,
                            rate,
                            isPercent,
                            finalAmount,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.shade100,
                              child: Icon(Icons.percent, color: Colors.amber.shade700),
                            ),
                            title: Text(
                              'Table $table • $noteName',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Serveur: $server',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (discountClientName != null && discountClientName.isNotEmpty)
                                  Text(
                                    'Client: $discountClientName',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                Text(
                                  'Taux: ${rate.toString()}${isPercent ? '%' : ' TND'} • Remise: ${_formatCurrency(finalDiscountAmount)}',
                                ),
                                Text(
                                  'Sous-total: ${_formatCurrency(finalSubtotal)} • Total: ${_formatCurrency(finalAmount)} • ${_formatDate(timestamp)}',
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Voir ticket',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.receipt_long, color: Colors.amber.shade700),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerChip({
    required String label,
    required double total,
    required int count,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required ValueChanged<bool> onSelected,
  }) {
    final currency = _formatCurrency(total);
    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: selectedColor,
      checkmarkColor: Colors.white,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
          Text(
            currency,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
          Text(
            '$count remises',
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white70 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? selectedColor : Colors.grey.shade300),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Aucune remise pour ce filtre',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
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

  void _showTicketDialog(
    BuildContext context,
    Map<String, dynamic> discount,
    String table,
    String server,
    String noteName,
    String? discountClientName,
    String timestamp,
    List<Map<String, dynamic>> items,
    double subtotal,
    double discountAmount,
    dynamic rate,
    bool isPercent,
    double finalAmount,
  ) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ticket de remise',
                        style: TextStyle(
                          fontSize: 18,
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
                PaymentTicketCard(
                  table: table,
                  server: server,
                  noteName: noteName,
                  timestamp: timestamp,
                  items: items,
                  subtotal: subtotal,
                  discountAmount: discountAmount,
                  discount: (rate as num?)?.toDouble(),
                  isPercentDiscount: isPercent,
                  amount: finalAmount,
                  paymentMode: discount['paymentMode'] as String?,
                  covers: discount['covers'] as int?,
                  discountClientName: discountClientName,
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
      ),
    );
  }
}

class _ServerStats {
  double total;
  int count;
  _ServerStats({this.total = 0.0, this.count = 0});
}

