import 'package:flutter/material.dart';
import '../widgets/paid_ticket_dialog.dart';

class PaidHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> paidPayments;

  const PaidHistoryPage({
    super.key,
    required this.paidPayments,
  });

  @override
  State<PaidHistoryPage> createState() => _PaidHistoryPageState();
}

class _PaidHistoryPageState extends State<PaidHistoryPage> {
  String? _selectedTable;

  @override
  Widget build(BuildContext context) {
    final tablesMap = <String, List<Map<String, dynamic>>>{};
    for (final payment in widget.paidPayments) {
      final table = payment['table']?.toString() ?? '?';
      if (!tablesMap.containsKey(table)) {
        tablesMap[table] = [];
      }
      tablesMap[table]!.add(payment);
    }

    if (_selectedTable != null && tablesMap.containsKey(_selectedTable)) {
      return _TableServicesPage(
        tableNumber: _selectedTable!,
        payments: tablesMap[_selectedTable]!,
        onBack: () => setState(() => _selectedTable = null),
      );
    }

    final sortedTables = tablesMap.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments, color: Colors.green),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Historique des encaissements',
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
                '${sortedTables.length} table(s)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: sortedTables.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun paiement encaissé',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedTables.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tableNumber = sortedTables[index];
                final payments = tablesMap[tableNumber]!;
                final totalAmount = payments.fold<double>(
                  0.0,
                  (sum, p) {
                    final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
                    final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                    return sum + (enteredAmount ?? amount);
                  },
                );
                final server = payments.first['server']?.toString() ?? 'unknown';
                final firstPayment = payments.first;
                final lastPayment = payments.last;
                final firstDate = _formatDate(firstPayment['timestamp']?.toString());
                final lastDate = _formatDate(lastPayment['timestamp']?.toString());

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      tableNumber,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Table $tableNumber',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Text('Serveur: $server'),
                      Text('${payments.length} paiement(s) • $firstDate → $lastDate'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrency(totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => setState(() => _selectedTable = tableNumber),
                );
              },
            ),
    );
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
}

class _TableServicesPage extends StatefulWidget {
  final String tableNumber;
  final List<Map<String, dynamic>> payments;
  final VoidCallback onBack;

  const _TableServicesPage({
    required this.tableNumber,
    required this.payments,
    required this.onBack,
  });

  @override
  State<_TableServicesPage> createState() => _TableServicesPageState();
}

class _TableServicesPageState extends State<_TableServicesPage> {
  int? _selectedServiceIndex;

  @override
  Widget build(BuildContext context) {
    final services = _groupPaymentsByService(widget.payments);

    if (_selectedServiceIndex != null && services.containsKey(_selectedServiceIndex)) {
      return _ServiceDetailPage(
        tableNumber: widget.tableNumber,
        serviceNumber: _selectedServiceIndex!,
        payments: services[_selectedServiceIndex]!,
        onBack: () => setState(() => _selectedServiceIndex = null),
      );
    }

    final serviceEntries = services.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Table ${widget.tableNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${services.length} service(s)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: serviceEntries.isEmpty
          ? const Center(child: Text('Aucun service'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: serviceEntries.length,
              itemBuilder: (context, index) {
                final entry = serviceEntries[index];
                final serviceIndex = entry.key;
                final servicePayments = entry.value;
                final totalAmount = servicePayments.fold<double>(
                  0.0,
                  (sum, p) {
                    final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
                    final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                    return sum + (enteredAmount ?? amount);
                  },
                );
                final firstDate = _formatDate(servicePayments.first['timestamp']?.toString());
                final lastDate = _formatDate(servicePayments.last['timestamp']?.toString());
                
                final isSplitPayment = servicePayments.isNotEmpty && 
                    servicePayments.first['isSplitPayment'] == true;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '$serviceIndex',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text('Service #$serviceIndex'),
                        if (isSplitPayment) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Paiement divisé',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstDate → $lastDate'),
                        const SizedBox(height: 4),
                        Text('${servicePayments.length} paiement(s) • ${_formatCurrency(totalAmount)}'),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                    onTap: () => setState(() => _selectedServiceIndex = serviceIndex),
                  ),
                );
              },
            ),
    );
  }

  Map<int, List<Map<String, dynamic>>> _groupPaymentsByService(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> splitPaymentGroups = {};
    final List<Map<String, dynamic>> nonSplitPayments = [];
    
    for (final payment in payments) {
      final isSplit = payment['isSplitPayment'] == true;
      final splitId = payment['splitPaymentId']?.toString();
      
      if (isSplit && splitId != null && splitId.isNotEmpty) {
        if (!splitPaymentGroups.containsKey(splitId)) {
          splitPaymentGroups[splitId] = [];
        }
        splitPaymentGroups[splitId]!.add(payment);
      } else {
        nonSplitPayments.add(payment);
      }
    }
    
    final List<Map<String, dynamic>> consolidatedPayments = [];
    
    for (final group in splitPaymentGroups.values) {
      if (group.isNotEmpty) {
        consolidatedPayments.add(group.first);
      }
    }
    
    consolidatedPayments.addAll(nonSplitPayments);
    
    consolidatedPayments.sort((a, b) {
      final timeA = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
      final timeB = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
      return timeA.compareTo(timeB);
    });

    final Map<int, List<Map<String, dynamic>>> services = {};
    int currentServiceIndex = 0;
    DateTime? lastPaymentTime;

    const serviceGapMinutes = 30;

    for (final payment in consolidatedPayments) {
      final timestamp = payment['timestamp']?.toString();
      if (timestamp == null) continue;

      final paymentTime = DateTime.tryParse(timestamp);
      if (paymentTime == null) continue;

      bool isNewService = false;
      if (lastPaymentTime == null) {
        isNewService = true;
      } else {
        final gap = paymentTime.difference(lastPaymentTime);
        if (gap.inMinutes > serviceGapMinutes) {
          isNewService = true;
        }
      }

      if (isNewService) {
        currentServiceIndex++;
        services[currentServiceIndex] = [];
      }

      final isSplit = payment['isSplitPayment'] == true;
      final splitId = payment['splitPaymentId']?.toString();
      
      if (isSplit && splitId != null && splitId.isNotEmpty && splitPaymentGroups.containsKey(splitId)) {
        services[currentServiceIndex]!.addAll(splitPaymentGroups[splitId]!);
      } else {
        services[currentServiceIndex]!.add(payment);
      }
      
      lastPaymentTime = paymentTime;
    }

    return services;
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
}

class _ServiceDetailPage extends StatelessWidget {
  final String tableNumber;
  final int serviceNumber;
  final List<Map<String, dynamic>> payments;
  final VoidCallback onBack;

  const _ServiceDetailPage({
    required this.tableNumber,
    required this.serviceNumber,
    required this.payments,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = payments.fold<double>(
      0.0,
      (sum, p) {
        final enteredAmount = (p['enteredAmount'] as num?)?.toDouble();
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + (enteredAmount ?? amount);
      },
    );

    final allItems = <Map<String, dynamic>>[];
    double totalSubtotal = 0.0;
    double totalDiscountAmount = 0.0;
    
    final isSplitPayment = payments.isNotEmpty && 
        payments.first['isSplitPayment'] == true &&
        payments.first['splitPaymentId'] != null;
    
    if (isSplitPayment && payments.isNotEmpty) {
      final firstPayment = payments.first;
      final items = (firstPayment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final item in items) {
        allItems.add(Map<String, dynamic>.from(item));
      }
      totalSubtotal = allItems.fold<double>(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        return sum + (price * quantity);
      });
      final discountRate = (firstPayment['discount'] as num?)?.toDouble() ?? 0.0;
      final isPercentDiscount = firstPayment['isPercentDiscount'] == true;
      if (isPercentDiscount && discountRate > 0) {
        totalDiscountAmount = totalSubtotal * (discountRate / 100);
      } else {
        totalDiscountAmount = discountRate;
      }
    } else {
      for (final payment in payments) {
        final items = (payment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final item in items) {
          final existingIndex = allItems.indexWhere(
            (i) => i['id'] == item['id'] && i['name'] == item['name'],
          );
          if (existingIndex != -1) {
            allItems[existingIndex]['quantity'] = (allItems[existingIndex]['quantity'] as int) + (item['quantity'] as int? ?? 0);
          } else {
            allItems.add(Map<String, dynamic>.from(item));
          }
        }
      }
      totalSubtotal = allItems.fold<double>(0.0, (sum, item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        return sum + (price * quantity);
      });
      if (payments.isNotEmpty) {
        double sumDiscountAmounts = 0.0;
        for (final payment in payments) {
          final paymentDiscountAmount = (payment['discountAmount'] as num?)?.toDouble() ?? 0.0;
          if (paymentDiscountAmount > 0.01) {
            sumDiscountAmounts += paymentDiscountAmount;
          }
        }
        totalDiscountAmount = sumDiscountAmounts;
      }
    }

    String? paymentModeDisplay = 'MIXTE';
    if (isSplitPayment) {
      final modes = payments.map((p) => p['paymentMode']?.toString() ?? '').where((m) => m.isNotEmpty).toSet();
      if (modes.length == 1) {
        paymentModeDisplay = modes.first;
      } else {
        paymentModeDisplay = 'MIXTE (${modes.length} modes)';
      }
    }
    
    final ticketTotal = totalSubtotal - totalDiscountAmount;
    
    double discountRate = 0.0;
    bool isPercentDiscount = false;
    if (totalDiscountAmount > 0.01 && totalSubtotal > 0.01) {
      discountRate = (totalDiscountAmount / totalSubtotal) * 100;
      isPercentDiscount = true;
    }
    
    double totalExcessAmount = 0.0;
    
    bool hasCashInPayment = false;
    for (final payment in payments) {
      if (payment['hasCashInPayment'] == true) {
        hasCashInPayment = true;
        break;
      }
    }
    
    if (!hasCashInPayment && totalAmount > ticketTotal) {
      totalExcessAmount = totalAmount - ticketTotal;
    }
    
    final paymentDetails = <Map<String, dynamic>>[];
    if (isSplitPayment) {
      final processedTxs = <String>{};
      for (final payment in payments) {
        final enteredAmount = (payment['enteredAmount'] as num?)?.toDouble() ?? 
            ((payment['amount'] as num?)?.toDouble() ?? 0.0);
        final paymentMode = payment['paymentMode']?.toString() ?? '';
        final txKey = '${paymentMode}_${enteredAmount.toStringAsFixed(3)}';
        if (!processedTxs.contains(txKey)) {
          processedTxs.add(txKey);
          paymentDetails.add({
            'mode': paymentMode,
            'amount': enteredAmount,
          });
        }
      }
    } else {
      for (final payment in payments) {
        final enteredAmount = (payment['enteredAmount'] as num?)?.toDouble() ?? 
            ((payment['amount'] as num?)?.toDouble() ?? 0.0);
        final paymentMode = payment['paymentMode']?.toString() ?? '';
        paymentDetails.add({
          'mode': paymentMode,
          'amount': enteredAmount,
        });
      }
    }
    
    final mainTicket = {
      'table': tableNumber,
      'date': payments.first['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'items': allItems,
      'subtotal': totalSubtotal,
      'discount': discountRate,
      'isPercentDiscount': isPercentDiscount,
      'discountAmount': totalDiscountAmount,
      'total': ticketTotal,
      'excessAmount': totalExcessAmount > 0.01 ? totalExcessAmount : null,
      'covers': payments.first['covers'] ?? 1,
      'server': payments.first['server'] ?? 'unknown',
      'paymentMode': paymentModeDisplay,
      'isSplitPayment': isSplitPayment,
      'paymentDetails': paymentDetails,
      'totalAmount': totalAmount,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text('Table $tableNumber - Service #$serviceNumber'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Ticket Principal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${_formatCurrency(ticketTotal)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    if (totalExcessAmount > 0.01) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pourboire ${(payments.first['server']?.toString() ?? 'unknown').toUpperCase()}: ${_formatCurrency(totalExcessAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Montant encaissé: ${_formatCurrency(totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => PaidTicketDialog(ticket: mainTicket),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Voir le ticket principal'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tickets de paiement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...payments.map((payment) {
              final noteName = payment['noteName']?.toString() ?? 'Note Principale';
              final paymentMode = payment['paymentMode']?.toString() ?? 'N/A';
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              final ticket = payment['ticket'] as Map<String, dynamic>?;
              final isSplitPayment = payment['isSplitPayment'] == true;
              
              final effectiveTicket = ticket ?? (isSplitPayment ? {
                'table': payment['table']?.toString() ?? '—',
                'date': payment['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
                'items': (payment['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                'subtotal': (payment['subtotal'] as num?)?.toDouble() ?? 0.0,
                'discount': (payment['discount'] as num?)?.toDouble() ?? 0.0,
                'discountAmount': (payment['discountAmount'] as num?)?.toDouble() ?? 0.0,
                'isPercentDiscount': payment['isPercentDiscount'] == true,
                'total': (payment['amount'] as num?)?.toDouble() ?? 0.0,
                'covers': payment['covers'] ?? 1,
                'server': payment['server']?.toString() ?? 'unknown',
                'paymentMode': payment['paymentMode']?.toString(),
                'isSplitPayment': true,
              } : null);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      paymentMode == 'ESPECE' ? Icons.money : Icons.credit_card,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text('$noteName • ${_getPaymentModeLabel(paymentMode)}'),
                      ),
                      if (isSplitPayment) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Divisé',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(_formatDate(payment['timestamp']?.toString())),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrency(amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (effectiveTicket != null)
                        IconButton(
                          icon: const Icon(Icons.receipt_long),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => PaidTicketDialog(ticket: effectiveTicket),
                            );
                          },
                          tooltip: 'Voir le ticket',
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
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

  String _getPaymentModeLabel(String? mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
        return 'Carte';
      case 'CHEQUE':
        return 'Chèque';
      case 'TPE':
        return 'TPE';
      default:
        return mode ?? '—';
    }
  }
}

